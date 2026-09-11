// Supabase Edge Function: ai-coach
//
// The only place in this system that holds the AI provider key.
//
// The app posts a conversation here and gets an answer back; it never holds a
// key and never talks to the provider directly. That is the whole point of the
// function: a key shipped inside an IPA is a key that anyone with the IPA has,
// and there is no way to rotate it out of a build that is already installed.
//
// Deploy with:
//   supabase functions deploy ai-coach
//   supabase secrets set OPENAI_API_KEY=sk-...        # never in the repo
//
// `verify_jwt` is on (see supabase/config.toml), so only a request carrying a
// valid Supabase session token from this project reaches the code below.

const OPENAI_URL = "https://api.openai.com/v1/chat/completions";

/** Overridable per project; the client's label is informational. */
const MODEL = Deno.env.get("AI_MODEL") ?? "gpt-4o-mini";

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

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    // Configuration, not the caller's fault. Logged without the key or the body.
    console.error("ai-coach: OPENAI_API_KEY is not set on this project");
    return json({ error: "AI backend is not configured" }, 503);
  }

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

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);

  try {
    const upstream = await fetch(OPENAI_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        messages: parsed.messages,
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
});
