# `ai-coach` Edge Function

The AI coach's backend. It is the only place in this system that holds the
provider key.

```
iPhone app  ──►  Supabase Edge Function (this)  ──►  OpenAI-compatible provider
                 holds AI_API_KEY
```

The provider is configuration, not code. Anything that speaks the
OpenAI-compatible Chat Completions protocol works — OpenAI, Alibaba DashScope
(Qwen) in compatible mode, and others. Nothing in the function names a provider,
an endpoint or a model.

The app posts a conversation here with the user's Supabase session token and
gets an answer back. What it must never do is talk to the provider directly
while carrying a key: a key inside an IPA is a key anyone with the IPA has, and
it cannot be rotated out of a build that is already installed.

## Status

**The code is here; it has not been deployed.** Nothing in this repository can
deploy it — that needs project credentials, which are deliberately not in the
repo. Until the two commands below are run, the iOS app's AI coach will fail
with `ai_error_unavailable` ("AI 教练暂时无法响应，请稍后重试。"), which is the
intended behaviour for a backend that is not there.

## Deploying

```sh
supabase link --project-ref <your-project-ref>

# All three are secrets on the project, never committed.
supabase secrets set AI_API_KEY=... AI_BASE_URL=... AI_MODEL=...

supabase functions deploy ai-coach
```

## Configuration

All three are required, and none has a default. A default endpoint would send
one provider's key to another provider, and a default model is a hardcoded model
name — the thing this indirection exists to remove. A deployment missing any of
them answers `503` and names the missing variable in the log, never to the
caller.

| Variable | Meaning |
|---|---|
| `AI_API_KEY` | The provider credential. Sent as `Authorization: Bearer`. |
| `AI_BASE_URL` | Either the base (`https://host/compatible-mode/v1`) or the full endpoint; `/chat/completions` is appended only when it is not already there. Must be `http(s)://`. |
| `AI_MODEL` | The model name the provider expects, e.g. `qwen-plus`. Passed through verbatim; this repository assumes nothing about which models a key may use. |

`OPENAI_API_KEY` is still read as a fallback for `AI_API_KEY`, so a deployment
configured under the old name keeps working. Use `AI_API_KEY` from now on; it
wins when both are set.

The endpoint is read from the server's own configuration on every request and is
never taken from the request body.

## Tests

```sh
deno test supabase/functions/ai-coach/
```

Every value in them is invented: a fake key, a fake endpoint, a fake provider.

## What the function does

- **Requires a signed-in user.** `verify_jwt = true` (see
  `supabase/config.toml`) means the platform rejects a request without a valid
  session token from this project before the code runs. Without that, this
  endpoint would be an open proxy onto the provider account.
- **Validates the request.** At most 40 messages, 4,000 characters each, 16,000
  in total. The client is trusted to be the app, not to be correct.
- **Answers in the app's language.** The body may carry a `locale` — one of the
  codes in `LANGUAGE_INSTRUCTIONS`, currently `en`, `he` and `zh-Hans`. The
  matching instruction is appended to the system message the app already sent,
  rather than added as a second system turn. The list is closed: an absent or
  unrecognised value adds nothing, so a caller cannot write an instruction of
  its own through this field.
- **Never returns provider or key material.** A provider error is logged as a
  status code and answered with a generic failure; the body is not echoed.
- **Times out at 25 seconds** so a stuck upstream cannot hold the request open
  until the platform's own limit.

## What it deliberately does not do

- It does not log message contents or anything that identifies the user.
- It does not store conversations. The only record of a chat is on the device
  (`CDChatMessage`).
- It does not expose the key to the client in any response, including errors.
