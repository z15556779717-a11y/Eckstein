// Supabase Edge Function: ai-coach
//
// The only place in this system that holds the AI provider key.
//
// The app posts a conversation here and gets an answer back; it never holds a
// key and never talks to the provider directly. That is the whole point of the
// function: a key shipped inside an IPA is a key that anyone with the IPA has,
// and there is no way to rotate it out of a build that is already installed.
//
// The provider is deployment configuration, not code -- see `handler.ts`. This
// file only starts the server.
//
// Deploy with:
//   supabase functions deploy ai-coach
//   supabase secrets set AI_API_KEY=... AI_BASE_URL=... AI_MODEL=...
//   # never in the repo
//
// `verify_jwt` is on (see supabase/config.toml), so only a request carrying a
// valid Supabase session token from this project reaches the code below.

import { createHandler } from "./handler.ts";

Deno.serve(createHandler({
  getEnv: (name) => Deno.env.get(name),
  fetch: (input, init) => fetch(input, init),
}));
