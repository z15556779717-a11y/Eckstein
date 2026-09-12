-- ============================================================================
-- Baseline schema
-- ============================================================================
-- The complete table set the app expects remotely, as a single migration that
-- a fresh, empty Supabase project can apply.
--
-- Provenance: derived from `FINAL_VERSION_APP_DB.sql` in the repository root,
-- which is the old project's master schema dump. That file is a script a human
-- ran by hand against a database they were willing to erase, and it is kept as
-- a historical reference. A migration cannot be that, so three things were
-- removed rather than translated:
--
--   * 19 `DROP TABLE IF EXISTS ... CASCADE` statements. On a fresh database
--     they are no-ops; on any other database they silently delete every row of
--     every table. A migration that runs automatically must not contain the
--     means to do that.
--   * 12 `TO anon` policies scoped to a hardcoded fake test user. The original
--     file labelled them "development only / Remove these policies in
--     production!". They grant the unauthenticated `anon` role write access,
--     and they reference a user id that will never exist on a real project.
--   * The two INSERTs that seeded that fake test user (id
--     `00000000-0000-0000-0000-000000000001`, email `test@example.com`) and its
--     preferences row. A production schema must not ship a well-known account.
--
-- Everything else is unchanged, including the `auth.uid() = user_id` policies,
-- the 29 indexes and the 31 foreign keys. The product semantics of the schema
-- are the original's.
--
-- Ordering: the timestamp sorts before `20260910120000_nutrition_fields.sql`,
-- which ALTERs four of the tables created here.
--
-- Applying this is a deliberate, manual step. It is not applied by the commit
-- that adds it.
-- ============================================================================

BEGIN;

-- Eckstein App Complete Database Schema
-- This is the master schema file for all tables
-- Version: 1.1
-- Date: 2025-01-17
-- Updated: Added carb load support and milk consumptions tracking


-- ==========================================
-- USERS AND AUTHENTICATION
-- ==========================================

-- Users table (mirrors auth.users but with app-specific data)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    display_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    last_synced_at TIMESTAMPTZ,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error'))
    -- NOTE: Foreign key to auth.users removed to allow independent table creation
    -- Add this constraint later if needed: CONSTRAINT fk_auth_user FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- User preferences table
CREATE TABLE user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    daily_calorie_goal INTEGER DEFAULT 2000 NOT NULL,
    daily_protein_goal INTEGER DEFAULT 150 NOT NULL,
    daily_carb_goal INTEGER DEFAULT 250 NOT NULL,
    weight_unit TEXT DEFAULT 'kg' CHECK (weight_unit IN ('kg', 'lbs')) NOT NULL,
    height_cm INTEGER,
    activity_level TEXT DEFAULT 'moderate' NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID,
    UNIQUE(user_id)
);

-- ==========================================
-- EXERCISE AND WORKOUT TABLES
-- ==========================================

-- Exercises reference table
CREATE TABLE exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    muscle_group TEXT,
    equipment TEXT,
    is_custom BOOLEAN DEFAULT false NOT NULL,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID
);

-- Workout types table (for templates)
CREATE TABLE workout_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    last_used TIMESTAMPTZ,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID
);

-- Workout type exercises (exercises in a workout template)
CREATE TABLE workout_type_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_type_id UUID NOT NULL REFERENCES workout_types(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises(id),
    order_index INTEGER DEFAULT 0 NOT NULL,
    target_sets INTEGER DEFAULT 3 NOT NULL,
    target_reps INTEGER DEFAULT 10 NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID
);

-- Workouts table
CREATE TABLE workouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    workout_type_id UUID REFERENCES workout_types(id),
    name TEXT NOT NULL,
    date DATE NOT NULL,
    duration_minutes INTEGER,
    notes TEXT,
    completed BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID
);

-- Workout sets table
CREATE TABLE workout_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_id UUID NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises(id),
    set_number INTEGER NOT NULL,
    weight_kg DECIMAL(6,2),
    reps INTEGER,
    target_reps INTEGER,
    completed BOOLEAN DEFAULT false NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID
);

-- ==========================================
-- NUTRITION AND DIET TABLES
-- ==========================================

-- Foods table
CREATE TABLE foods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    brand TEXT,
    barcode TEXT,
    category TEXT,
    calories_per_100g INTEGER NOT NULL,
    protein_per_100g DECIMAL(5,2) NOT NULL,
    carbs_per_100g DECIMAL(5,2) NOT NULL,
    fat_per_100g DECIMAL(5,2) NOT NULL,
    fiber_per_100g DECIMAL(5,2) DEFAULT 0,
    serving_size DECIMAL(6,2) DEFAULT 100,
    serving_unit TEXT DEFAULT 'g',
    is_custom BOOLEAN DEFAULT false NOT NULL,
    is_favorite BOOLEAN DEFAULT false NOT NULL,
    is_verified BOOLEAN DEFAULT false NOT NULL,
    last_used TIMESTAMPTZ,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID
);

-- Meals table
CREATE TABLE meals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID
);

-- Meal items table
CREATE TABLE meal_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meal_id UUID NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
    food_id UUID NOT NULL REFERENCES foods(id),
    quantity_grams DECIMAL(7,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID
);

-- ==========================================
-- ECKSTEIN DIET TABLES
-- ==========================================

-- Eckstein foods table
CREATE TABLE eckstein_foods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    daily_grams INTEGER DEFAULT 0 NOT NULL,
    is_fat BOOLEAN DEFAULT false NOT NULL,
    is_custom BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID
);

-- Eckstein meals table
CREATE TABLE eckstein_meals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    meal_number INTEGER DEFAULT 1 NOT NULL CHECK (meal_number >= 1),
    is_carb_load BOOLEAN DEFAULT false NOT NULL,
    total_calories INTEGER DEFAULT 0,
    total_protein DECIMAL(5,2) DEFAULT 0,
    total_carbs DECIMAL(5,2) DEFAULT 0,
    total_fat DECIMAL(5,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID,
    UNIQUE(user_id, date, meal_number)
);

-- Eckstein meal entries table
CREATE TABLE eckstein_meal_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meal_id UUID NOT NULL REFERENCES eckstein_meals(id) ON DELETE CASCADE,
    food_name TEXT NOT NULL,
    category TEXT NOT NULL,
    grams_consumed INTEGER DEFAULT 0 NOT NULL,
    calories INTEGER DEFAULT 0 NOT NULL,
    protein DECIMAL(5,2) DEFAULT 0 NOT NULL,
    carbs DECIMAL(5,2) DEFAULT 0 NOT NULL,
    fat DECIMAL(5,2) DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID
);

-- ==========================================
-- WEIGHT AND BODY METRICS
-- ==========================================

-- Weight entries table
CREATE TABLE weight_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    weight_kg DECIMAL(5,2) NOT NULL,
    date DATE NOT NULL,
    source TEXT DEFAULT 'manual' NOT NULL,
    body_fat_percentage DECIMAL(4,2),
    muscle_mass DECIMAL(5,2),
    notes TEXT,
    photo_path TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID,
    UNIQUE(user_id, date)
);

-- ==========================================
-- CALORIE BANK
-- ==========================================

-- Calorie bank table
CREATE TABLE calorie_bank (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    calories_saved INTEGER DEFAULT 0 NOT NULL,
    food_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID,
    UNIQUE(user_id, date)
);

-- ==========================================
-- FAT MEAL TRACKER
-- ==========================================

-- Fat meal tracker table
CREATE TABLE fat_meal_tracker (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    week_start_date DATE NOT NULL,
    fat_meals_consumed INTEGER DEFAULT 0 NOT NULL CHECK (fat_meals_consumed >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID,
    UNIQUE(user_id, week_start_date)
);

-- ==========================================
-- CARB LOAD TRACKER
-- ==========================================

-- Carb load tracker table
CREATE TABLE carb_load_tracker (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    week_start_date DATE NOT NULL,
    carb_load_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID,
    UNIQUE(user_id, week_start_date)
);

-- ==========================================
-- MILK CONSUMPTIONS
-- ==========================================

-- Milk consumptions table
CREATE TABLE milk_consumptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    ml_consumed INTEGER DEFAULT 0 NOT NULL CHECK (ml_consumed >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID,
    UNIQUE(user_id, date)
);

-- ==========================================
-- AI COACH
-- ==========================================

-- Chat messages table
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_user BOOLEAN NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'error')),
    remote_id UUID
);

-- ==========================================
-- INDEXES FOR PERFORMANCE
-- ==========================================

-- User indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_sync_status ON users(sync_status);

-- Workout indexes
CREATE INDEX idx_workouts_user_date ON workouts(user_id, date);
CREATE INDEX idx_workouts_sync_status ON workouts(sync_status);
CREATE INDEX idx_workout_sets_workout_id ON workout_sets(workout_id);
CREATE INDEX idx_workout_types_user_id ON workout_types(user_id);
CREATE INDEX idx_workout_type_exercises_type_id ON workout_type_exercises(workout_type_id);

-- Nutrition indexes
CREATE INDEX idx_meals_user_date ON meals(user_id, date);
CREATE INDEX idx_meals_sync_status ON meals(sync_status);
CREATE INDEX idx_meal_items_meal_id ON meal_items(meal_id);
CREATE INDEX idx_foods_name ON foods(name);
CREATE INDEX idx_foods_barcode ON foods(barcode);

-- Eckstein diet indexes
CREATE INDEX idx_eckstein_meals_user_date ON eckstein_meals(user_id, date);
CREATE INDEX idx_eckstein_meals_sync_status ON eckstein_meals(sync_status);
CREATE INDEX idx_eckstein_meal_entries_meal_id ON eckstein_meal_entries(meal_id);

-- Weight and metrics indexes
CREATE INDEX idx_weight_entries_user_date ON weight_entries(user_id, date);
CREATE INDEX idx_weight_entries_sync_status ON weight_entries(sync_status);

-- Calorie bank indexes
CREATE INDEX idx_calorie_bank_user_date ON calorie_bank(user_id, date);
CREATE INDEX idx_calorie_bank_sync_status ON calorie_bank(sync_status);

-- Fat meal tracker indexes
CREATE INDEX idx_fat_meal_tracker_user_week ON fat_meal_tracker(user_id, week_start_date);
CREATE INDEX idx_fat_meal_tracker_sync_status ON fat_meal_tracker(sync_status);

-- Carb load tracker indexes
CREATE INDEX idx_carb_load_tracker_user_week ON carb_load_tracker(user_id, week_start_date);
CREATE INDEX idx_carb_load_tracker_sync_status ON carb_load_tracker(sync_status);

-- Milk consumptions indexes
CREATE INDEX idx_milk_consumptions_user_date ON milk_consumptions(user_id, date);
CREATE INDEX idx_milk_consumptions_sync_status ON milk_consumptions(sync_status);

-- Chat indexes
CREATE INDEX idx_chat_messages_user_id ON chat_messages(user_id);
CREATE INDEX idx_chat_messages_timestamp ON chat_messages(user_id, timestamp);

-- Exercise indexes
CREATE INDEX idx_exercises_name ON exercises(name);
CREATE INDEX idx_exercises_category ON exercises(category);

-- ==========================================
-- TRIGGERS
-- ==========================================

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_preferences_updated_at ON user_preferences;
CREATE TRIGGER update_user_preferences_updated_at BEFORE UPDATE ON user_preferences
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS update_workouts_updated_at ON workouts;
CREATE TRIGGER update_workouts_updated_at BEFORE UPDATE ON workouts
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS update_eckstein_meals_updated_at ON eckstein_meals;
CREATE TRIGGER update_eckstein_meals_updated_at BEFORE UPDATE ON eckstein_meals
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS update_fat_meal_tracker_updated_at ON fat_meal_tracker;
CREATE TRIGGER update_fat_meal_tracker_updated_at BEFORE UPDATE ON fat_meal_tracker
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS update_carb_load_tracker_updated_at ON carb_load_tracker;
CREATE TRIGGER update_carb_load_tracker_updated_at BEFORE UPDATE ON carb_load_tracker
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS update_milk_consumptions_updated_at ON milk_consumptions;
CREATE TRIGGER update_milk_consumptions_updated_at BEFORE UPDATE ON milk_consumptions
    FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- ==========================================
-- ROW LEVEL SECURITY (RLS)
-- ==========================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_type_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE eckstein_foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE eckstein_meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE eckstein_meal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE weight_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE calorie_bank ENABLE ROW LEVEL SECURITY;
ALTER TABLE fat_meal_tracker ENABLE ROW LEVEL SECURITY;
ALTER TABLE carb_load_tracker ENABLE ROW LEVEL SECURITY;
ALTER TABLE milk_consumptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (users can only access their own data)
-- Users table
CREATE POLICY "Users can view own profile" ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);

-- User preferences
CREATE POLICY "Users can manage own preferences" ON user_preferences FOR ALL USING (auth.uid() = user_id);

-- Workouts
CREATE POLICY "Users can manage own workouts" ON workouts FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own workout types" ON workout_types FOR ALL USING (auth.uid() = user_id);

-- Exercises (public read, authenticated create)
CREATE POLICY "Anyone can view exercises" ON exercises FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create exercises" ON exercises FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Foods (public read, authenticated create)
CREATE POLICY "Anyone can view foods" ON foods FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create foods" ON foods FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Meals and nutrition
CREATE POLICY "Users can manage own meals" ON meals FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own eckstein meals" ON eckstein_meals FOR ALL USING (auth.uid() = user_id);

-- Weight entries
CREATE POLICY "Users can manage own weight entries" ON weight_entries FOR ALL USING (auth.uid() = user_id);

-- Calorie bank
CREATE POLICY "Users can manage own calorie bank" ON calorie_bank FOR ALL USING (auth.uid() = user_id);

-- Fat meal tracker
CREATE POLICY "Users can manage own fat meal tracker" ON fat_meal_tracker FOR ALL USING (auth.uid() = user_id);

-- Carb load tracker
CREATE POLICY "Users can manage own carb load tracker" ON carb_load_tracker FOR ALL USING (auth.uid() = user_id);

-- Milk consumptions
CREATE POLICY "Users can manage own milk consumptions" ON milk_consumptions FOR ALL USING (auth.uid() = user_id);

-- Chat messages
CREATE POLICY "Users can manage own chat messages" ON chat_messages FOR ALL USING (auth.uid() = user_id);

-- Dependent tables policies
CREATE POLICY "Users can manage workout sets" ON workout_sets FOR ALL 
    USING (EXISTS (SELECT 1 FROM workouts WHERE workouts.id = workout_sets.workout_id AND workouts.user_id = auth.uid()));

CREATE POLICY "Users can manage workout type exercises" ON workout_type_exercises FOR ALL 
    USING (EXISTS (SELECT 1 FROM workout_types WHERE workout_types.id = workout_type_exercises.workout_type_id AND workout_types.user_id = auth.uid()));

CREATE POLICY "Users can manage meal items" ON meal_items FOR ALL 
    USING (EXISTS (SELECT 1 FROM meals WHERE meals.id = meal_items.meal_id AND meals.user_id = auth.uid()));

CREATE POLICY "Users can manage eckstein meal entries" ON eckstein_meal_entries FOR ALL 
    USING (EXISTS (SELECT 1 FROM eckstein_meals WHERE eckstein_meals.id = eckstein_meal_entries.meal_id AND eckstein_meals.user_id = auth.uid()));


-- ==========================================
-- NOTES ON DIFFERENCES FROM CORE DATA
-- ==========================================

-- 1. CDCalorieBank.caloriesSaved -> calorie_bank.calories_saved (matches Core Data property name)
-- 2. CDCalorieBank.foodName -> calorie_bank.food_name (stored as text field)
-- 3. CDWeightEntry includes photo_path field for photo storage
-- 4. CDChatMessage.isUser (boolean) -> chat_messages.is_user (boolean, not role enum)
-- 5. All tables include sync_status and remote_id for sync functionality
-- 6. Users table references auth.users for authentication integration
-- 7. CDEcksteinMeal.isCarbLoad -> eckstein_meals.is_carb_load (boolean field for carb load meals)
-- 8. Added carb_load_tracker table to track weekly carb load usage (similar to fat_meal_tracker)
-- 9. Added milk_consumptions table to track daily milk consumption in ml
COMMIT;
