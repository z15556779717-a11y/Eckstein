# `ai-coach` Edge Function

The AI coach's backend. It is the only place in this system that holds the
provider key.

```
iPhone app  ──►  Supabase Edge Function (this)  ──►  OpenAI
                 holds OPENAI_API_KEY
```

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

# The key is set as a secret on the project, never committed.
supabase secrets set OPENAI_API_KEY=sk-...

supabase functions deploy ai-coach
```

`AI_MODEL` is optional and defaults to `gpt-4o-mini`.

## What the function does

- **Requires a signed-in user.** `verify_jwt = true` (see
  `supabase/config.toml`) means the platform rejects a request without a valid
  session token from this project before the code runs. Without that, this
  endpoint would be an open proxy onto the provider account.
- **Validates the request.** At most 40 messages, 4,000 characters each, 16,000
  in total. The client is trusted to be the app, not to be correct.
- **Never returns provider or key material.** A provider error is logged as a
  status code and answered with a generic failure; the body is not echoed.
- **Times out at 25 seconds** so a stuck upstream cannot hold the request open
  until the platform's own limit.

## What it deliberately does not do

- It does not log message contents or anything that identifies the user.
- It does not store conversations. The only record of a chat is on the device
  (`CDChatMessage`).
- It does not expose the key to the client in any response, including errors.
