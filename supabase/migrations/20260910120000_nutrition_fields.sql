-- ============================================================================
-- Nutrition fields migration
-- ============================================================================
-- Phase 2 of the nutrition data unification added nutrition columns to the
-- official Core Data entities (`CDEcksteinFood`, `CDEcksteinMeal`,
-- `CDEcksteinMealEntry`, `CDUserPreferences`). See NUTRITION_MIGRATION_PLAN.md
-- §12 for the reasoning.
--
-- THIS FILE IS PREPARED, NOT APPLIED.
--
-- It is deliberately conservative:
--
--   * Idempotent — `ADD COLUMN IF NOT EXISTS` only, so re-running is a no-op.
--   * Non-destructive — no DROP, no DELETE, no TRUNCATE, no data rewrite.
--     Existing rows keep their values; new columns are nullable or defaulted.
--   * No secrets — not a key, token or credential appears in this file. It is
--     meant to be applied with the `supabase` CLI or the dashboard SQL editor,
--     never with a service_role key embedded in the app.
--
-- Before applying it, confirm it against the LIVE schema rather than trusting
-- this repo's copy of it:
--
--   supabase db diff --linked
--
-- The caveat §12 recorded — `SyncManager.encodeEntity` writing `CDEcksteinFood`
-- through its generic branch, which sent the *Core Data attribute names* verbatim
-- (`dailyGrams`, `isCustom`, `createdAt`, …) while the schema uses snake_case
-- (`daily_grams`, `is_custom`, `created_at`, …) — is fixed in phase 3: that
-- branch now encodes `NutritionFoodDTO`, whose `CodingKeys` are the column names
-- below. The same change gave `eckstein_meal_entries` its real column names
-- (`food_name` / `grams_consumed` / `category`, previously sent as `name` /
-- `quantity_grams` / `meal_type`) and stopped `syncCreate` from injecting
-- `user_id` into tables that have no such column.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- eckstein_foods — per-100g nutrition and catalog metadata
-- ----------------------------------------------------------------------------
-- The table already has: id, name, category, daily_grams, is_fat, is_custom,
-- created_at, sync_status, remote_id.
ALTER TABLE eckstein_foods
    ADD COLUMN IF NOT EXISTS barcode            TEXT,
    ADD COLUMN IF NOT EXISTS brand              TEXT,
    ADD COLUMN IF NOT EXISTS calories_per_100g  DECIMAL(7,2),
    ADD COLUMN IF NOT EXISTS protein_per_100g   DECIMAL(6,2),
    ADD COLUMN IF NOT EXISTS carbs_per_100g     DECIMAL(6,2),
    ADD COLUMN IF NOT EXISTS fat_per_100g       DECIMAL(6,2),
    ADD COLUMN IF NOT EXISTS fiber_per_100g     DECIMAL(6,2),
    ADD COLUMN IF NOT EXISTS food_category      TEXT,
    ADD COLUMN IF NOT EXISTS serving_size       DECIMAL(7,2),
    ADD COLUMN IF NOT EXISTS serving_unit       TEXT,
    ADD COLUMN IF NOT EXISTS is_favorite        BOOLEAN DEFAULT false NOT NULL,
    ADD COLUMN IF NOT EXISTS is_verified        BOOLEAN DEFAULT false NOT NULL,
    ADD COLUMN IF NOT EXISTS last_used          TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS source             TEXT,
    ADD COLUMN IF NOT EXISTS updated_at         TIMESTAMPTZ DEFAULT NOW() NOT NULL;

-- Mirrors NutritionService.upsertFood(from:source:), which matches scanned and
-- seeded products on barcode, then on name + food_category. Partial so the many
-- NULL barcodes do not collide.
CREATE UNIQUE INDEX IF NOT EXISTS idx_eckstein_foods_barcode
    ON eckstein_foods (barcode)
    WHERE barcode IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_eckstein_foods_name_category
    ON eckstein_foods (name, food_category);

-- ----------------------------------------------------------------------------
-- eckstein_meals — meal slot and fiber total
-- ----------------------------------------------------------------------------
-- The table already has: total_calories, total_protein, total_carbs, total_fat,
-- created_at, updated_at.
ALTER TABLE eckstein_meals
    ADD COLUMN IF NOT EXISTS meal_type   TEXT,
    ADD COLUMN IF NOT EXISTS total_fiber DECIMAL(6,2);

-- Optional rather than NOT NULL: existing rows predate the meal slot and are
-- read back as `MealType.unspecified` by `MealType(storedValue:)`. A default
-- would invent a slot for every historical meal.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'eckstein_meals_meal_type_check'
    ) THEN
        ALTER TABLE eckstein_meals
            ADD CONSTRAINT eckstein_meals_meal_type_check
            CHECK (meal_type IS NULL
                   OR meal_type IN ('breakfast', 'lunch', 'dinner', 'snack'));
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- eckstein_meal_entries — fiber snapshot and updated_at
-- ----------------------------------------------------------------------------
-- The table already has calories, protein, carbs and fat, so the entry-level
-- nutrition snapshot was already supported remotely. Only fiber and updated_at
-- are new.
ALTER TABLE eckstein_meal_entries
    ADD COLUMN IF NOT EXISTS fiber      DECIMAL(6,2),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL;

-- The four snapshot columns were created `NOT NULL DEFAULT 0`, which cannot
-- express "unknown": a row that predates nutrition tracking would read back as a
-- genuinely zero-calorie entry. The Core Data attributes are nullable for exactly
-- that reason (`NUTRITION_MIGRATION_PLAN.md` §5.2), and `NutritionMealEntryDTO`
-- omits the key when the value is `nil`. Dropping `NOT NULL` is non-destructive —
-- existing rows keep the values they hold — and lets the remote side carry the
-- same distinction. `grams_consumed` stays `NOT NULL`: it is a non-optional
-- scalar locally and `0` is a real weight there, not a missing one.
ALTER TABLE eckstein_meal_entries
    ALTER COLUMN calories DROP NOT NULL,
    ALTER COLUMN protein  DROP NOT NULL,
    ALTER COLUMN carbs    DROP NOT NULL,
    ALTER COLUMN fat      DROP NOT NULL;

-- ----------------------------------------------------------------------------
-- user_preferences — fat and fiber goals
-- ----------------------------------------------------------------------------
-- The table already has daily_calorie_goal, daily_protein_goal and
-- daily_carb_goal, all NOT NULL with defaults. The two new goals are nullable:
-- a goal the user has not set must stay distinguishable from a goal of zero, so
-- `DailyNutritionGoals` keeps it as `nil` rather than defaulting it here.
ALTER TABLE user_preferences
    ADD COLUMN IF NOT EXISTS daily_fat_goal   DECIMAL(6,2),
    ADD COLUMN IF NOT EXISTS daily_fiber_goal DECIMAL(6,2);

COMMIT;
