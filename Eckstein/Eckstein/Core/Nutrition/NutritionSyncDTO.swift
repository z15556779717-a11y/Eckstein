//
//  NutritionSyncDTO.swift
//  Eckstein
//
//  Explicit wire shapes for the four nutrition entities.
//
//  See NUTRITION_MIGRATION_PLAN.md §12.
//
//  Why these exist: `SyncManager.encodeEntity` used to build a `[String: Any]`
//  per entity by hand, and the nutrition branches had drifted away from the
//  schema — `eckstein_meal_entries` was sent `name` / `quantity_grams` /
//  `meal_type` where the table has `food_name` / `grams_consumed` / `category`,
//  `CDEcksteinFood` fell through to a generic branch that emitted Core Data
//  attribute names verbatim (`dailyGrams`, `isCustom`, …), and both nutrition
//  totals on a meal were hard-coded to zero. Nothing complained, because
//  PostgREST rejects the row server-side and the client only logs the failure.
//
//  A DTO per table makes the mismatch a compile-time/unit-test-time problem
//  instead: the property names are the local vocabulary, every `CodingKey` is a
//  column name from `FINAL_VERSION_APP_DB.sql` plus
//  `supabase/migrations/20260910120000_nutrition_fields.sql`, and a round trip
//  is one test.
//
//  NULL semantics. Every optional property is encoded with `encodeIfPresent`
//  (what the synthesised `Codable` conformance does for an `Optional`), so a
//  `nil` **omits the key** rather than sending `null`. For a column the reader
//  treats as "unknown" the two are the same, and omitting is the safer of the
//  two: it lets a server-side `DEFAULT` apply where one exists. The entry's
//  nutrition columns are nullable in the migration precisely so "unknown" stays
//  distinguishable from "zero" on the remote side too.
//

import Foundation
import CoreData

/// Table names and shared mapping facts for the nutrition entities.
enum NutritionSyncTable {
    static let foods = "eckstein_foods"
    static let meals = "eckstein_meals"
    static let mealEntries = "eckstein_meal_entries"
    static let preferences = "user_preferences"

    /// Tables with a `user_id` column — the ones a row must name its owner in.
    ///
    /// Read off `FINAL_VERSION_APP_DB.sql`, not guessed. The two that are
    /// *absent* are the point: `eckstein_meal_entries` is owned through its meal
    /// (`meal_id`, `ON DELETE CASCADE`) and `eckstein_foods` is a shared catalog.
    /// `SyncManager.syncCreate` used to inject `user_id` into every row
    /// regardless, which is a guaranteed failure on both.
    static let requireUserID: Set<String> = [
        "user_preferences",
        "workout_types",
        "workouts",
        "meals",
        "eckstein_meals",
        "weight_entries",
        "calorie_bank",
        "fat_meal_tracker",
        "carb_load_tracker",
        "milk_consumptions",
        "chat_messages"
    ]

    /// Whether a table has a `user_id` column.
    static func requiresUserID(_ table: String) -> Bool {
        requireUserID.contains(table)
    }
}

/// The JSON coding used for every nutrition DTO.
///
/// One place, so the encoder that wrote a row and the decoder a test reads it
/// back with cannot disagree about dates.
enum NutritionSyncCoding {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Deterministic output, so a test can compare bytes rather than hope.
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// A `TIMESTAMPTZ` value.
    static func timestamp(_ date: Date?) -> Date? { date }

    /// A Postgres `DATE` column (`eckstein_meals.date`), which is a calendar day
    /// with no time and no zone — so it is written as `YYYY-MM-DD` in UTC, the
    /// same shape the previous encoder used, rather than as an instant.
    static let dateOnlyFormat = "yyyy-MM-dd"

    static func dateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = dateOnlyFormat
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

// MARK: - Foods

/// One row of `eckstein_foods`.
struct NutritionFoodDTO: Codable, Equatable {
    var id: UUID
    var name: String
    /// The Eckstein `DietCategory` raw value. Empty for a catalog row — the
    /// column is `NOT NULL`, so this is `""` and not `nil` for those.
    var category: String
    var dailyGrams: Int
    var isFat: Bool
    var isCustom: Bool

    var barcode: String?
    var brand: String?
    var caloriesPer100g: Double?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
    var fiberPer100g: Double?
    var foodCategory: String?
    var servingSize: Double?
    var servingUnit: String?
    var isFavorite: Bool
    var isVerified: Bool
    var lastUsed: Date?
    var source: String?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, category, barcode, brand, source
        case dailyGrams = "daily_grams"
        case isFat = "is_fat"
        case isCustom = "is_custom"
        case caloriesPer100g = "calories_per_100g"
        case proteinPer100g = "protein_per_100g"
        case carbsPer100g = "carbs_per_100g"
        case fatPer100g = "fat_per_100g"
        case fiberPer100g = "fiber_per_100g"
        case foodCategory = "food_category"
        case servingSize = "serving_size"
        case servingUnit = "serving_unit"
        case isFavorite = "is_favorite"
        case isVerified = "is_verified"
        case lastUsed = "last_used"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension NutritionFoodDTO {
    /// Maps a catalog row. `nil` when the row has no `id`, which is the one
    /// field the remote primary key cannot invent.
    init?(food: CDEcksteinFood, now: Date = Date()) {
        guard let id = food.id else { return nil }
        self.init(
            id: id,
            name: food.name ?? "",
            category: food.category ?? "",
            dailyGrams: Int(food.dailyGrams),
            isFat: food.isFat,
            isCustom: food.isCustom,
            barcode: food.barcode,
            brand: food.brand,
            caloriesPer100g: food.caloriesPer100g?.doubleValue,
            proteinPer100g: food.proteinPer100g?.doubleValue,
            carbsPer100g: food.carbsPer100g?.doubleValue,
            fatPer100g: food.fatPer100g?.doubleValue,
            fiberPer100g: food.fiberPer100g?.doubleValue,
            foodCategory: food.foodCategory,
            servingSize: food.servingSize?.doubleValue,
            servingUnit: food.servingUnit,
            isFavorite: food.isFavorite,
            isVerified: food.isVerified,
            lastUsed: food.lastUsed,
            source: food.source,
            createdAt: food.createdAt ?? now,
            updatedAt: food.updatedAt ?? now
        )
    }
}

// MARK: - Meals

/// One row of `eckstein_meals`.
struct NutritionMealDTO: Codable, Equatable {
    var id: UUID
    var userID: UUID?
    /// `YYYY-MM-DD` — the column is a Postgres `DATE`, not an instant.
    var date: String
    var mealNumber: Int
    var isCarbLoad: Bool
    var mealType: String?
    var totalCalories: Int
    var totalProtein: Double
    var totalCarbs: Double
    var totalFat: Double
    var totalFiber: Double?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, date
        case userID = "user_id"
        case mealNumber = "meal_number"
        case isCarbLoad = "is_carb_load"
        case mealType = "meal_type"
        case totalCalories = "total_calories"
        case totalProtein = "total_protein"
        case totalCarbs = "total_carbs"
        case totalFat = "total_fat"
        case totalFiber = "total_fiber"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension NutritionMealDTO {
    /// Maps a meal.
    ///
    /// The totals are read from the entity's cached columns, which
    /// `NutritionService.recalculateTotals` keeps in step with the entries. The
    /// columns are nullable in Core Data, so a meal whose totals were never
    /// computed reads as zero rather than blocking the row — the same reading
    /// `NutritionAggregator` takes.
    init?(meal: CDEcksteinMeal, now: Date = Date()) {
        guard let id = meal.id else { return nil }
        // `meal.date` is nullable locally while the column is `NOT NULL`, so a
        // row with no date is filed under the moment it was encoded rather than
        // dropped — it is still a real meal with real entries.
        let day = meal.date ?? now
        self.init(
            id: id,
            userID: meal.user?.id,
            date: NutritionSyncCoding.dateOnly(day),
            mealNumber: Int(meal.mealNumber),
            isCarbLoad: meal.isCarbLoad,
            mealType: meal.mealType,
            totalCalories: Int((meal.totalCalories?.doubleValue ?? 0).rounded()),
            totalProtein: meal.totalProtein?.doubleValue ?? 0,
            totalCarbs: meal.totalCarbs?.doubleValue ?? 0,
            totalFat: meal.totalFat?.doubleValue ?? 0,
            totalFiber: meal.totalFiber?.doubleValue,
            // The entity has no `createdAt`; the day the meal belongs to is the
            // honest stand-in, and the column is `NOT NULL DEFAULT NOW()`.
            createdAt: day,
            updatedAt: meal.updatedAt ?? now
        )
    }
}

// MARK: - Meal entries

/// One row of `eckstein_meal_entries`.
struct NutritionMealEntryDTO: Codable, Equatable {
    var id: UUID
    /// The owning meal. This is what makes the row a user's — the table has no
    /// `user_id` column.
    var mealID: UUID?
    var foodName: String
    var category: String
    var gramsConsumed: Int
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var fiber: Double?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, category, calories, protein, carbs, fat, fiber
        case mealID = "meal_id"
        case foodName = "food_name"
        case gramsConsumed = "grams_consumed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension NutritionMealEntryDTO {
    /// Maps a log entry.
    ///
    /// `calories` is an `INTEGER` column and the snapshot is a `Double`, so it is
    /// rounded — the same rounding the local entity already went through when the
    /// value was written.
    init?(entry: CDEcksteinMealEntry) {
        guard let id = entry.id else { return nil }
        self.init(
            id: id,
            mealID: entry.meal?.id,
            foodName: entry.foodName ?? "",
            category: entry.category ?? "",
            gramsConsumed: Int(entry.gramsConsumed),
            calories: entry.calories.map { ($0.doubleValue).rounded() },
            protein: entry.protein?.doubleValue,
            carbs: entry.carbs?.doubleValue,
            fat: entry.fat?.doubleValue,
            fiber: entry.fiber?.doubleValue,
            // The entity has no `createdAt`; omitted, so the server's
            // `DEFAULT NOW()` applies rather than an invented timestamp.
            createdAt: nil,
            updatedAt: entry.updatedAt
        )
    }
}

// MARK: - Preferences

/// The nutrition columns of `user_preferences`.
///
/// Only the goals and the fields the existing encoder already sent — this is not
/// a DTO for the whole preferences row.
struct NutritionPreferencesDTO: Codable, Equatable {
    var id: UUID
    var userID: UUID?
    var dailyCalorieGoal: Int
    var dailyProteinGoal: Int
    var dailyCarbGoal: Int
    var dailyFatGoal: Double?
    var dailyFiberGoal: Double?
    var weightUnit: String
    var heightCm: Int?
    var activityLevel: String

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case dailyCalorieGoal = "daily_calorie_goal"
        case dailyProteinGoal = "daily_protein_goal"
        case dailyCarbGoal = "daily_carb_goal"
        case dailyFatGoal = "daily_fat_goal"
        case dailyFiberGoal = "daily_fiber_goal"
        case weightUnit = "weight_unit"
        case heightCm = "height_cm"
        case activityLevel = "activity_level"
    }
}

extension NutritionPreferencesDTO {
    /// Maps a preferences row.
    ///
    /// `height_cm` is nullable remotely and a non-optional `Int32` locally, so a
    /// stored zero — which is what "never set" looks like on this entity — is
    /// sent as absent rather than as a person 0 cm tall. The two fallbacks for
    /// `weight_unit` and `activity_level` match the columns' own `DEFAULT`s, and
    /// are needed because both are `NOT NULL` remotely.
    init?(preferences: CDUserPreferences) {
        guard let id = preferences.id else { return nil }
        self.init(
            id: id,
            userID: preferences.user?.id,
            dailyCalorieGoal: Int(preferences.dailyCalorieGoal),
            dailyProteinGoal: Int(preferences.dailyProteinGoal),
            dailyCarbGoal: Int(preferences.dailyCarbGoal),
            dailyFatGoal: preferences.dailyFatGoal?.doubleValue,
            dailyFiberGoal: preferences.dailyFiberGoal?.doubleValue,
            weightUnit: preferences.weightUnit ?? "kg",
            heightCm: preferences.heightCm > 0 ? Int(preferences.heightCm) : nil,
            activityLevel: preferences.activityLevel ?? "moderate"
        )
    }
}

// MARK: - Encoding

extension NutritionSyncCoding {
    /// Encodes a DTO for the sync queue. `nil` when the DTO cannot be encoded,
    /// which the caller treats as "nothing to send" rather than as a crash.
    static func encode<T: Encodable>(_ value: T) -> Data? {
        try? makeEncoder().encode(value)
    }
}
