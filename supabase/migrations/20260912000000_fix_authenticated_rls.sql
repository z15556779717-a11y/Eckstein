-- ============================================================================
-- Authenticated write access the app actually performs
-- ============================================================================
--
-- The baseline turned row-level security on for 19 tables and gave most of them
-- a policy. Four are missing the one the app needs for its own writes, which
-- shows up as `new row violates row-level security policy` the first time a
-- signed-in user does anything.
--
--   * `users`          — had SELECT and UPDATE but no INSERT. The app upserts
--                        its profile row immediately after sign-in
--                        (`SimpleUserSync.syncCurrentUserToDatabase`), and
--                        nothing else creates that row: there is no
--                        `handle_new_user` trigger on `auth.users`. Every table
--                        whose `user_id` references `users(id)` is unusable
--                        until that row exists, and the sync layer swallows the
--                        error, so the failure is silent.
--   * `eckstein_foods` — RLS enabled with no policy at all, so every statement
--                        was denied. This is pre-existing rather than
--                        introduced by the baseline: `FINAL_VERSION_APP_DB.sql`
--                        enabled RLS on this table and never wrote a policy for
--                        it either.
--   * `exercises`      — SELECT and INSERT only. The sync queue also updates
--                        and deletes these.
--   * `foods`          — same as `exercises`.
--
-- Every policy below is `TO authenticated`. None names `anon`, and the write
-- checks are written so that a statement cannot create or touch a row that
-- belongs to somebody else.
--
-- Deliberately not addressed, because it is not expressible: `eckstein_foods`,
-- `exercises` and `foods` have no owner column the client populates. The two
-- catalog tables have a `created_by` column, but nothing in the iOS sync layer
-- ever sets it, so scoping their writes by `created_by = auth.uid()` would deny
-- the app its own rows rather than protect anyone else's. Their INSERT policy
-- was already open to any signed-in user; UPDATE and DELETE are brought onto
-- the same footing rather than tightened here, and a follow-up that populates
-- `created_by` on the client is what would let these be scoped properly.

BEGIN;

-- ---------------------------------------------------------------------------
-- users
-- ---------------------------------------------------------------------------
-- The profile row is the app's own, and only its own: `WITH CHECK` is what
-- stops a signed-in user from inserting a row under another user's id, and the
-- primary key makes a second row for the same account impossible. There is no
-- DELETE policy, because the app never deletes a profile.
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
CREATE POLICY "Users can insert own profile" ON users
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- eckstein_foods
-- ---------------------------------------------------------------------------
-- A shared catalog with no owner column, so the boundary available is
-- "signed in" rather than "yours". Scoped to `authenticated`: an unauthenticated
-- request is denied outright, which is what the app requires anyway.
DROP POLICY IF EXISTS "Authenticated users can view eckstein foods" ON eckstein_foods;
CREATE POLICY "Authenticated users can view eckstein foods" ON eckstein_foods
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Authenticated users can add eckstein foods" ON eckstein_foods;
CREATE POLICY "Authenticated users can add eckstein foods" ON eckstein_foods
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can update eckstein foods" ON eckstein_foods;
CREATE POLICY "Authenticated users can update eckstein foods" ON eckstein_foods
    FOR UPDATE TO authenticated
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can delete eckstein foods" ON eckstein_foods;
CREATE POLICY "Authenticated users can delete eckstein foods" ON eckstein_foods
    FOR DELETE TO authenticated
    USING (auth.uid() IS NOT NULL);

-- ---------------------------------------------------------------------------
-- exercises and foods
-- ---------------------------------------------------------------------------
-- Both already allowed a signed-in user to read everything and insert anything.
-- The sync queue also updates and deletes rows in both, so the two verbs are
-- added at the same level the INSERT already sits at rather than a new one.
DROP POLICY IF EXISTS "Authenticated users can update exercises" ON exercises;
CREATE POLICY "Authenticated users can update exercises" ON exercises
    FOR UPDATE TO authenticated
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can delete exercises" ON exercises;
CREATE POLICY "Authenticated users can delete exercises" ON exercises
    FOR DELETE TO authenticated
    USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can update foods" ON foods;
CREATE POLICY "Authenticated users can update foods" ON foods
    FOR UPDATE TO authenticated
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can delete foods" ON foods;
CREATE POLICY "Authenticated users can delete foods" ON foods
    FOR DELETE TO authenticated
    USING (auth.uid() IS NOT NULL);

COMMIT;

-- ============================================================================
-- Re-running this migration is safe: every CREATE is preceded by a DROP of the
-- same name, so it converges rather than failing on the second application.
-- Row-level security is left enabled on every table; no policy here widens one
-- that already exists, and none of them is granted to `anon`.
-- ============================================================================
