// Supabase Edge Function: ai-coach — request handling.
//
// Separate from `index.ts` so a test can import it. Importing the entrypoint
// would start a server, which a test must not do.
//
// The function speaks the OpenAI-compatible Chat Completions protocol, which
// several providers now implement — OpenAI, Alibaba DashScope (Qwen) and others
// behind a compatible-mode endpoint. Which one is in use is deployment
// configuration, not code: nothing here names a provider, an endpoint or a
// model, and nothing here reads the model from the request.

export interface ProviderConfig {
  apiKey: string;
  url: string;
  model: string;
}

export interface ProviderDeps {
  getEnv: (name: string) => string | undefined;
  fetch: typeof fetch;
}

const MAX_MESSAGES = 40;
const MAX_CONTENT_CHARS = 4000;
const MAX_TOTAL_CHARS = 16000;
const MAX_OUTPUT_TOKENS = 1000;
const UPSTREAM_TIMEOUT_MS = 25_000;

type Role = "system" | "user" | "assistant";

interface ChatMessage {
  role: Role;
  content: string;
}

function firstNonEmpty(...values: (string | undefined)[]): string | undefined {
  for (const value of values) {
    const trimmed = value?.trim();
    if (trimmed) return trimmed;
  }
  return undefined;
}

/**
 * The URL to POST to, given whatever form of base URL was configured.
 *
 * A provider documents its "base URL" as the prefix a client appends to, so
 * `https://host/compatible-mode/v1` and `https://host/compatible-mode/v1/chat/completions`
 * both mean the same thing to a person pasting one into a secret. Accepting
 * both means neither silently becomes `.../chat/completions/chat/completions`.
 */
export function chatCompletionsURL(baseUrl: string): string {
  const trimmed = baseUrl.trim().replace(/\/+$/, "");
  return trimmed.endsWith("/chat/completions") ? trimmed : `${trimmed}/chat/completions`;
}

/**
 * The provider configuration, or which variable is missing or unusable.
 *
 * All three are required. None of them has a default: a default endpoint sends
 * one provider's key to another provider, and a default model is a hardcoded
 * model name — the thing this indirection exists to remove. A deployment that
 * is not configured is answered by `createHandler` with a 503 rather than
 * guessed at.
 */
export function resolveConfig(
  getEnv: (name: string) => string | undefined,
): { config: ProviderConfig } | { problem: string } {
  // OPENAI_API_KEY is the name this function used before it became
  // provider-agnostic. It is still read so a deployment configured under the
  // old name keeps working; AI_API_KEY is the name to configure from now on and
  // wins when both are present.
  const apiKey = firstNonEmpty(getEnv("AI_API_KEY"), getEnv("OPENAI_API_KEY"));
  if (!apiKey) return { problem: "AI_API_KEY" };

  const baseUrl = firstNonEmpty(getEnv("AI_BASE_URL"));
  if (!baseUrl) return { problem: "AI_BASE_URL" };
  // A base URL without a scheme is a host, not a URL. Catching it here keeps
  // the failure at "not configured" instead of a confusing upstream error.
  if (!/^https?:\/\//i.test(baseUrl)) return { problem: "AI_BASE_URL" };

  const model = firstNonEmpty(getEnv("AI_MODEL"));
  if (!model) return { problem: "AI_MODEL" };

  return { config: { apiKey, url: chatCompletionsURL(baseUrl), model } };
}

/**
 * A message the provider will accept, or an explanation of why it will not.
 *
 * The client is trusted to be the app, not to be correct: a stale build, a
 * retry, or anything else holding a valid token can post here, and a request
 * with a null inside `messages` would otherwise become a provider error the
 * user sees as "the coach is broken".
 */
function parseMessages(value: unknown): { messages: ChatMessage[] } | { error: string } {
  if (!Array.isArray(value) || value.length === 0) {
    return { error: "messages must be a non-empty array" };
  }
  if (value.length > MAX_MESSAGES) {
    return { error: `messages must contain at most ${MAX_MESSAGES} entries` };
  }

  const messages: ChatMessage[] = [];
  let total = 0;

  for (const entry of value) {
    if (typeof entry !== "object" || entry === null) {
      return { error: "each message must be an object" };
    }
    const { role, content } = entry as Record<string, unknown>;

    if (role !== "system" && role !== "user" && role !== "assistant") {
      return { error: "each message needs a role of system, user or assistant" };
    }
    if (typeof content !== "string" || content.trim().length === 0) {
      return { error: "each message needs non-empty content" };
    }
    if (content.length > MAX_CONTENT_CHARS) {
      return { error: `a message must be at most ${MAX_CONTENT_CHARS} characters` };
    }

    total += content.length;
    messages.push({ role, content });
  }

  if (total > MAX_TOTAL_CHARS) {
    return { error: `the conversation must be at most ${MAX_TOTAL_CHARS} characters` };
  }

  return { messages };
}

/**
 * The languages the app may ask to be answered in, and what each one means.
 *
 * An allowlist rather than free text, because this value arrives in the request
 * body and ends up inside the prompt: passing it through would let any caller
 * holding a token write its own system instruction. A code that is not on the
 * list is dropped rather than refused — the conversation is still answerable,
 * and a build newer than this deployment should get an answer, not an error.
 */
const LANGUAGE_INSTRUCTIONS: Record<string, string> = {
  en: "Answer in English.",
  he: "Answer in Hebrew (עברית).",
  "zh-Hans": "Answer in Simplified Chinese (简体中文).",
};

/** Longer than any language tag the app sends; anything longer is not one. */
const MAX_LOCALE_CHARS = 35;

function parseLocale(value: unknown): string | undefined {
  if (typeof value !== "string" || value.length > MAX_LOCALE_CHARS) return undefined;
  // `hasOwnProperty.call`, not `LANGUAGE_INSTRUCTIONS[value]`: a caller sending
  // "__proto__" or "constructor" would otherwise reach the prototype and get a
  // function where the prompt expects a sentence.
  return Object.prototype.hasOwnProperty.call(LANGUAGE_INSTRUCTIONS, value) ? value : undefined;
}

/**
 * The conversation to send, with the language directive attached.
 *
 * Appended to the system message the app already sends rather than added as a
 * second one: the app's prompt is where "how to answer" already lives, and a
 * second system turn would have the provider weighing two voices. Appended, not
 * prepended, so the app's description of the coach is read first and this reads
 * as a rider on it. A conversation with no system message gets one, so the
 * directive is never silently dropped.
 */
function withLanguage(messages: ChatMessage[], locale: string | undefined): ChatMessage[] {
  const instruction = locale ? LANGUAGE_INSTRUCTIONS[locale] : undefined;
  if (!instruction) return messages;

  const [first, ...rest] = messages;
  if (first.role === "system") {
    return [{ role: "system", content: `${first.content}\n\n${instruction}` }, ...rest];
  }
  return [{ role: "system", content: instruction }, ...messages];
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/**
 * The request handler, with the environment and the network passed in.
 *
 * Injected rather than reached for directly so a test can supply a fake
 * provider and a fake environment without patching globals — and so the
 * endpoint cannot come from the request: it is read from the server's own
 * configuration on every call and is never a parameter.
 */
export function createHandler(deps: ProviderDeps): (request: Request) => Promise<Response> {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return json({ error: "method not allowed" }, 405);
    }

    const resolved = resolveConfig(deps.getEnv);
    if ("problem" in resolved) {
      // Configuration, not the caller's fault. The variable's *name* is logged
      // and not returned: what this deployment is missing is not the caller's
      // business, and a value is never logged at all.
      console.error(`ai-coach: ${resolved.problem} is not set on this project`);
      return json({ error: "AI backend is not configured" }, 503);
    }
    const { apiKey, url, model } = resolved.config;

    let payload: Record<string, unknown>;
    try {
      payload = await request.json();
    } catch {
      return json({ error: "body must be JSON" }, 400);
    }

    const parsed = parseMessages(payload.messages);
    if ("error" in parsed) {
      return json({ error: parsed.error }, 400);
    }

    const temperature = typeof payload.temperature === "number" && payload.temperature >= 0 &&
        payload.temperature <= 2
      ? payload.temperature
      : 0.7;

    // Absent from every build that predates the language field, which is why it
    // is optional here and why an unknown value is ignored instead of rejected.
    const locale = parseLocale(payload.locale);

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);

    try {
      const upstream = await deps.fetch(url, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          messages: withLanguage(parsed.messages, locale),
          temperature,
          max_tokens: MAX_OUTPUT_TOKENS,
          stream: false,
        }),
        signal: controller.signal,
      });

      if (!upstream.ok) {
        // The provider's own message can echo request details, so it is logged
        // here and not returned.
        console.error(`ai-coach: provider responded ${upstream.status}`);
        const status = upstream.status === 429 ? 429 : 502;
        return json({ error: "the AI provider could not answer" }, status);
      }

      const data = await upstream.json();
      const content = data?.choices?.[0]?.message?.content;

      if (typeof content !== "string" || content.trim().length === 0) {
        console.error("ai-coach: provider returned no content");
        return json({ error: "the AI provider returned no content" }, 502);
      }

      return json({
        content,
        usage: {
          prompt_tokens: data?.usage?.prompt_tokens ?? 0,
          completion_tokens: data?.usage?.completion_tokens ?? 0,
          total_tokens: data?.usage?.total_tokens ?? 0,
        },
      });
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") {
        console.error("ai-coach: provider timed out");
        return json({ error: "the AI provider timed out" }, 504);
      }
      console.error("ai-coach: request failed");
      return json({ error: "the AI provider could not be reached" }, 502);
    } finally {
      clearTimeout(timeout);
    }
  };
}
