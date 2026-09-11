//
//  NutritionIntegrationTests.swift
//  EcksteinTests
//
//  Created by Eliad Shahar on 11/09/2026.
//

import XCTest
import CoreData
import HealthKit
@testable import Eckstein

/// Builds a stand-in Open Food Facts response.
///
/// A free function rather than a method so the closures handed to
/// `BarcodeFoodResolver` capture nothing — an async closure that captured the
/// test case would have to be `Sendable`, and `XCTestCase` is not.
private func productResponse(
    name: String = "Scanned Bar",
    code: String = "1234567890123",
    calories: Double? = 380,
    protein: Double? = 33,
    carbs: Double? = 36,
    fat: Double? = 15,
    fiber: Double? = 25
) -> FoodAPIResponse {
    FoodAPIResponse(
        product: FoodAPIResponse.Product(
            productName: name,
            brands: "Test Brand",
            nutriments: FoodAPIResponse.Nutriments(
                energyKcal100g: calories,
                proteins100g: protein,
                carbohydrates100g: carbs,
                fat100g: fat,
                fiber100g: fiber
            ),
            servingSize: "60 g",
            code: code
        ),
        status: 1,
        statusVerbose: "product found"
    )
}

/// Phase 3's integration coverage: the twenty-five cases the brief lists, run
/// against the real `NutritionService`, the real `CDEcksteinFood` catalog and an
/// in-memory store built from the current compiled model.
///
/// The split from `NutritionTests` is deliberate. That suite covers the pure
/// layer — the aggregator, the snapshot maths, the model version. This one covers
/// the *seams*: a logged meal reaching a snapshot, a seed reaching the catalog, a
/// DTO reaching the wire, a barcode reaching a stored row, and an export reaching
/// HealthKit. Those are the places Phase 3 changed, so they are the places that
/// need a test that would fail if the change were reverted.
///
/// Everything the tests cannot own is replaced at an explicit seam — the network
/// behind `BarcodeFoodResolver` and the store behind `NutritionHealthKitService` —
/// never by weakening the shipped implementation.
class NutritionIntegrationTests: XCTestCase {

    var controller: PersistenceController!
    var context: NSManagedObjectContext!
    var service: NutritionService!

    /// A fixed calendar, so nothing here depends on the machine's time zone.
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    /// A whole-second instant: `JSONEncoder`'s `.iso8601` drops fractional
    /// seconds, so a date carrying them would not survive a round trip and the
    /// round-trip test would fail for a reason that has nothing to do with the
    /// mapping it is checking.
    let epoch = Date(timeIntervalSince1970: 1_760_000_000)

    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        service = NutritionService(context: context)
    }

    override func tearDown() {
        service = nil
        context = nil
        controller = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Midday `daysAgo` days before today, in the fixed calendar.
    private func day(_ daysAgo: Int = 0) -> Date {
        let today = calendar.startOfDay(for: Date())
        let shifted = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        return calendar.date(byAdding: .hour, value: 12, to: shifted) ?? shifted
    }

    /// A catalog food with declared per-100 g values.
    @discardableResult
    private func makeFood(
        _ name: String,
        category: String = "",
        calories: Double? = nil,
        protein: Double? = nil,
        carbs: Double? = nil,
        fat: Double? = nil,
        fiber: Double? = nil,
        barcode: String? = nil,
        source: NutritionSource? = nil
    ) throws -> CDEcksteinFood {
        let food = CDEcksteinFood(context: context)
        food.id = UUID()
        food.name = name
        food.category = category
        food.dailyGrams = 0
        food.isCustom = false
        food.createdAt = epoch
        food.caloriesPer100g = calories.map { NSNumber(value: $0) }
        food.proteinPer100g = protein.map { NSNumber(value: $0) }
        food.carbsPer100g = carbs.map { NSNumber(value: $0) }
        food.fatPer100g = fat.map { NSNumber(value: $0) }
        food.fiberPer100g = fiber.map { NSNumber(value: $0) }
        food.barcode = barcode
        food.foodCategory = "Test"
        food.nutritionSource = source
        try context.save()
        return food
    }

    /// 200 kcal / 20 g protein / 10 g carbs / 5 g fat / 2 g fiber per 100 g.
    /// 150 g of it is 300 kcal / 30 / 15 / 7.5 / 3.
    @discardableResult
    private func makeReferenceFood(_ name: String = "Reference") throws -> CDEcksteinFood {
        try makeFood(name, calories: 200, protein: 20, carbs: 10, fat: 5, fiber: 2)
    }

    /// Logs through `NutritionService` — the only official write path.
    ///
    /// `foodName` is overridden rather than the row being omitted: passing `food`
    /// is what gives the entry per-100 g values, and a different name is what
    /// keeps it from merging into the entry already logged for the meal.
    @discardableResult
    private func log(
        _ food: CDEcksteinFood?,
        foodName: String? = nil,
        category: String? = nil,
        grams: Double,
        on date: Date,
        mealNumber: Int32 = 1,
        mealType: MealType? = nil
    ) throws -> CDEcksteinMealEntry {
        try service.logEntry(
            foodName: foodName ?? food?.name ?? "",
            category: category ?? food?.category,
            grams: grams,
            mealNumber: mealNumber,
            mealType: mealType,
            date: date,
            food: food,
            calendar: calendar
        )
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - 1. Per-100 g × grams

    func testSnapshotScalesPer100gValuesByGrams() throws {
        let per100g = NutritionSnapshot(calories: 200, protein: 20, carbs: 10, fat: 5, fiber: 2)

        let at150 = per100g.scaled(toGrams: 150)
        XCTAssertEqual(at150.calories, 300, accuracy: 0.0001)
        XCTAssertEqual(at150.protein, 30, accuracy: 0.0001)
        XCTAssertEqual(at150.carbs, 15, accuracy: 0.0001)
        XCTAssertEqual(at150.fat, 7.5, accuracy: 0.0001)
        XCTAssertEqual(at150.fiber, 3, accuracy: 0.0001)

        // Also through the optional-input entry point, which is what a catalog
        // row with a mix of declared and missing values goes through.
        let partial = try XCTUnwrap(NutritionSnapshot.per100g(
            calories: 200, protein: nil, carbs: 10, fat: nil, fiber: nil, grams: 50
        ))
        XCTAssertEqual(partial.calories, 100, accuracy: 0.0001)
        XCTAssertEqual(partial.carbs, 5, accuracy: 0.0001)
        XCTAssertEqual(partial.protein, 0, accuracy: 0.0001)

        // Nothing declared at all is "unknown", not a zero-calorie food.
        XCTAssertNil(NutritionSnapshot.per100g(
            calories: nil, protein: nil, carbs: nil, fat: nil, fiber: nil, grams: 100
        ))
    }

    // MARK: - 2-6. Each component reaches the entry's snapshot

    func testLoggingWritesEveryComponentToTheEntrySnapshot() throws {
        let food = try makeReferenceFood()
        let entry = try log(food, grams: 150, on: day())

        XCTAssertEqual(entry.gramsConsumed, 150)
        XCTAssertEqual(entry.calories?.doubleValue ?? -1, 300, accuracy: 0.0001)
        XCTAssertEqual(entry.protein?.doubleValue ?? -1, 30, accuracy: 0.0001)
        XCTAssertEqual(entry.carbs?.doubleValue ?? -1, 15, accuracy: 0.0001)
        XCTAssertEqual(entry.fat?.doubleValue ?? -1, 7.5, accuracy: 0.0001)
        XCTAssertEqual(entry.fiber?.doubleValue ?? -1, 3, accuracy: 0.0001)
        XCTAssertTrue(entry.hasNutritionData)
    }

    // MARK: - 3 (continued). History keeps its own values

    func testEditingTheCatalogDoesNotChangeAnAlreadyLoggedEntry() throws {
        let food = try makeReferenceFood()
        let entry = try log(food, grams: 100, on: day())
        XCTAssertEqual(entry.calories?.doubleValue ?? -1, 200, accuracy: 0.0001)

        // The catalog row is corrected after the fact.
        food.caloriesPer100g = NSNumber(value: 900)
        food.proteinPer100g = NSNumber(value: 90)
        try context.save()

        // The historical record is untouched…
        XCTAssertEqual(entry.calories?.doubleValue ?? -1, 200, accuracy: 0.0001)
        XCTAssertEqual(entry.protein?.doubleValue ?? -1, 20, accuracy: 0.0001)

        // …while a fresh edit re-reads the corrected values.
        try service.updateGrams(100, for: entry)
        XCTAssertEqual(entry.calories?.doubleValue ?? -1, 900, accuracy: 0.0001)
    }

    // MARK: - 7. Editing grams recomputes the snapshot

    func testUpdateGramsRecomputesTheSnapshot() throws {
        let food = try makeReferenceFood()
        let entry = try log(food, grams: 100, on: day())
        XCTAssertEqual(entry.calories?.doubleValue ?? -1, 200, accuracy: 0.0001)

        try service.updateGrams(250, for: entry)

        XCTAssertEqual(entry.gramsConsumed, 250)
        XCTAssertEqual(entry.calories?.doubleValue ?? -1, 500, accuracy: 0.0001)
        XCTAssertEqual(entry.fiber?.doubleValue ?? -1, 5, accuracy: 0.0001)
    }

    // MARK: - 8. Editing the food recomputes the snapshot

    func testUpdateEntryChangesFoodAndRecomputesTheSnapshot() throws {
        let original = try makeReferenceFood()
        let replacement = try makeFood("Replacement", calories: 50, protein: 1, carbs: 12, fat: 0.5, fiber: 4)

        let entry = try log(original, grams: 100, on: day())
        XCTAssertEqual(entry.calories?.doubleValue ?? -1, 200, accuracy: 0.0001)

        try service.updateEntry(
            entry,
            foodName: replacement.name ?? "",
            category: replacement.category,
            grams: 200,
            food: replacement
        )

        XCTAssertEqual(entry.foodName, "Replacement")
        XCTAssertEqual(entry.calories?.doubleValue ?? -1, 100, accuracy: 0.0001)
        XCTAssertEqual(entry.carbs?.doubleValue ?? -1, 24, accuracy: 0.0001)
        XCTAssertEqual(entry.fiber?.doubleValue ?? -1, 8, accuracy: 0.0001)
    }

    // MARK: - 9-10. Display metadata does not touch the snapshot

    /// The brief asks that editing `notes` leave the snapshot alone. This schema
    /// has no notes column on a meal entry — `MealDetailView`'s notes box is
    /// local view state, by its own comment — so the slot is the whole of the
    /// display metadata that can be edited, and this is the test for that rule.
    func testChangingMealTypeLeavesTheSnapshotAlone() throws {
        let food = try makeReferenceFood()
        let entry = try log(food, grams: 150, on: day(), mealNumber: 1, mealType: .breakfast)
        let before = entry.nutritionSnapshot

        try service.updateMealType(.dinner, for: entry)

        XCTAssertEqual(entry.nutritionSnapshot, before)
        XCTAssertEqual(entry.meal?.mealType, MealType.dinner.storedValue)
        XCTAssertEqual(entry.calories?.doubleValue ?? -1, 300, accuracy: 0.0001)

        // And the entry is reported under its new slot.
        let slots = try service.mealTypeSummary(for: day(), calendar: calendar)
        XCTAssertEqual(slots.map(\.mealType), [.dinner])
    }

    // MARK: - 11. Duplicating produces a new identity

    func testDuplicateProducesANewIdentityAndKeepsTheSnapshot() throws {
        let food = try makeReferenceFood()
        let original = try log(food, grams: 150, on: day())
        // Pinned, so the assertion below cannot be defeated by a coarse clock.
        original.updatedAt = epoch
        try context.save()

        let copy = try service.duplicate(original, calendar: calendar)

        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertNotEqual(copy.objectID, original.objectID)
        XCTAssertNotEqual(copy.updatedAt, original.updatedAt)
        XCTAssertEqual(copy.gramsConsumed, original.gramsConsumed)
        XCTAssertEqual(copy.nutritionSnapshot, original.nutritionSnapshot)

        // Two rows, not one row mutated.
        let entries = try service.entries(on: day(), calendar: calendar)
        XCTAssertEqual(entries.count, 2)
    }

    func testDeletingAnEntryRemovesItAndRefreshesTheMealTotals() throws {
        let food = try makeReferenceFood()
        let first = try log(food, grams: 100, on: day(), mealNumber: 1)
        let second = try log(food, foodName: "Other", grams: 100, on: day(), mealNumber: 2)
        XCTAssertEqual(second.meal?.totalCalories?.doubleValue ?? -1, 200, accuracy: 0.0001)

        try service.delete(second)

        let entries = try service.entries(on: day(), calendar: calendar)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.objectID, first.objectID)
    }

    func testLogAgainMergesIntoTheExistingEntryForTheDay() throws {
        let food = try makeReferenceFood()
        let entry = try log(food, grams: 100, on: day())

        try service.logAgain(entry, on: day(), calendar: calendar)

        let entries = try service.entries(on: day(), calendar: calendar)
        XCTAssertEqual(entries.count, 1, "logging the same food again merges rather than duplicating")
        XCTAssertEqual(entries.first?.gramsConsumed, 200)
        XCTAssertEqual(entries.first?.calories?.doubleValue ?? -1, 400, accuracy: 0.0001)
    }

    // MARK: - 12. Daily summary

    func testDailySummaryTotalsTheDaysEntries() throws {
        let food = try makeReferenceFood()
        try log(food, grams: 100, on: day(), mealNumber: 1, mealType: .breakfast)
        try log(food, foodName: "Second", grams: 50, on: day(), mealNumber: 2, mealType: .lunch)
        // A different day must not be counted.
        try log(food, foodName: "Yesterday", grams: 1000, on: day(1))

        let summary = try service.dailySummary(for: day(), calendar: calendar)

        XCTAssertEqual(summary.dailyCalories, 300, accuracy: 0.0001)
        XCTAssertEqual(summary.dailyProtein, 30, accuracy: 0.0001)
        XCTAssertEqual(summary.dailyCarbohydrates, 15, accuracy: 0.0001)
        XCTAssertEqual(summary.dailyFat, 7.5, accuracy: 0.0001)
        XCTAssertEqual(summary.dailyFiber, 3, accuracy: 0.0001)
        XCTAssertEqual(summary.entryCount, 2)
        XCTAssertFalse(summary.isEmpty)
    }

    func testDailySummaryOnADayWithNothingLoggedIsEmpty() throws {
        let summary = try service.dailySummary(for: day(), calendar: calendar)

        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.entryCount, 0)
        XCTAssertEqual(summary.totals, .zero)
    }

    /// A day is decided by `Calendar`, never by comparing two `Date`s: late
    /// evening and early morning are the same day if the calendar says so.
    func testDayBoundariesUseTheCalendarNotDateEquality() throws {
        let food = try makeReferenceFood()
        let noon = day()
        let lateEvening = calendar.date(byAdding: .hour, value: 9, to: noon) ?? noon
        let earlyMorning = calendar.date(byAdding: .hour, value: -11, to: noon) ?? noon

        try log(food, grams: 100, on: earlyMorning, mealNumber: 1)
        try log(food, foodName: "Evening", grams: 100, on: lateEvening, mealNumber: 2)

        let summary = try service.dailySummary(for: noon, calendar: calendar)
        XCTAssertEqual(summary.entryCount, 2)
        XCTAssertNotEqual(earlyMorning, lateEvening)
    }

    // MARK: - 13. Per-meal-slot summary

    func testMealTypeSummaryGroupsBySlot() throws {
        let food = try makeReferenceFood()
        try log(food, grams: 100, on: day(), mealNumber: 1, mealType: .breakfast)
        try log(food, foodName: "Lunch Food", grams: 50, on: day(), mealNumber: 2, mealType: .lunch)
        try log(food, foodName: "Snack Food", grams: 200, on: day(), mealNumber: 3, mealType: .snack)

        let slots = try service.mealTypeSummary(for: day(), calendar: calendar)

        XCTAssertEqual(slots.map(\.mealType), [.breakfast, .lunch, .snack])

        let breakfast = try XCTUnwrap(slots.first { $0.mealType == .breakfast })
        XCTAssertEqual(breakfast.nutrition.calories, 200, accuracy: 0.0001)

        let lunch = try XCTUnwrap(slots.first { $0.mealType == .lunch })
        XCTAssertEqual(lunch.nutrition.calories, 100, accuracy: 0.0001)
        XCTAssertEqual(lunch.totalGrams, 50, accuracy: 0.0001)

        // An empty slot is omitted rather than reported as a zero meal.
        XCTAssertNil(slots.first { $0.mealType == .dinner })
    }

    // MARK: - 14-16. Goals, remaining, and overshoot

    func testGoalProgressReportsCurrentTargetAndRemaining() throws {
        try service.setGoals(DailyNutritionGoals(
            calories: 2000, protein: 150, carbs: 200, fat: 60, fiber: 30
        ))

        let food = try makeReferenceFood()
        try log(food, grams: 100, on: day())

        let progress = try service.goalProgress(on: day(), calendar: calendar)

        XCTAssertEqual(progress.caloriesCurrent, 200, accuracy: 0.0001)
        XCTAssertEqual(progress.caloriesTarget ?? -1, 2000)
        XCTAssertEqual(progress.caloriesRemaining ?? -1, 1800, accuracy: 0.0001)
        XCTAssertEqual(progress.proteinCurrent, 20, accuracy: 0.0001)
        XCTAssertEqual(progress.proteinTarget ?? -1, 150)
        XCTAssertEqual(progress.fiberTarget ?? -1, 30)
        XCTAssertFalse(progress.calories.isOverTarget)
        XCTAssertFalse(progress.calories.isTargetMet)
    }

    /// 2200 kcal target, 2450 consumed → −250. The brief is explicit that this is
    /// not clamped to zero.
    func testRemainingGoesNegativeWhenOverTarget() throws {
        try service.setGoals(DailyNutritionGoals(calories: 2200))

        let dense = try makeFood("Dense", calories: 1000)
        try log(dense, grams: 245, on: day())

        let progress = try service.goalProgress(on: day(), calendar: calendar)

        XCTAssertEqual(progress.caloriesCurrent, 2450, accuracy: 0.0001)
        XCTAssertEqual(progress.caloriesRemaining ?? 0, -250, accuracy: 0.0001)
        XCTAssertTrue(progress.calories.isOverTarget)
        XCTAssertTrue(progress.calories.isTargetMet)
        XCTAssertEqual(progress.calories.progress ?? 0, 2450.0 / 2200.0, accuracy: 0.0001)
        // Only the display projection is clamped.
        XCTAssertEqual(progress.calories.displayProgress, 1)
    }

    func testAGoalThatWasNeverSetIsNilRatherThanZero() throws {
        try service.setGoals(DailyNutritionGoals(calories: 2000))

        let food = try makeReferenceFood()
        try log(food, grams: 100, on: day())

        let progress = try service.goalProgress(on: day(), calendar: calendar)

        XCTAssertEqual(progress.caloriesTarget ?? -1, 2000)
        XCTAssertNil(progress.fatTarget, "an unset goal is absent, not a goal of zero")
        XCTAssertNil(progress.fatRemaining)
        XCTAssertNil(progress.fatProgress)
        XCTAssertFalse(progress.fat.isOverTarget)
    }

    // MARK: - 17. NutritionSource mapping

    func testNutritionSourceRoundTripsEveryCase() {
        for source in NutritionSource.allCases {
            XCTAssertEqual(NutritionSource(storedValue: source.storedValue), source)
        }

        XCTAssertEqual(NutritionSource(storedValue: "barcode"), .barcode)
        XCTAssertEqual(NutritionSource(storedValue: " healthKit "), .healthKit)

        // An unrecognised or absent value is "provenance unrecorded", not a guess.
        XCTAssertNil(NutritionSource(storedValue: "something-new"))
        XCTAssertNil(NutritionSource(storedValue: ""))
        XCTAssertNil(NutritionSource(storedValue: nil))
    }

    func testCatalogRowCarriesItsProvenance() throws {
        let seeded = try makeFood("Seeded", calories: 100, source: .seed)
        XCTAssertEqual(seeded.nutritionSource, .seed)
        XCTAssertEqual(seeded.source, "seed")

        let scanned = try makeFood("Scanned", calories: 100, source: .barcode)
        XCTAssertEqual(scanned.nutritionSource, .barcode)

        // A row written before the field existed reads as `nil`.
        let legacy = try makeFood("Legacy", calories: 100)
        XCTAssertNil(legacy.nutritionSource)
    }

    // MARK: - 18-19. Supabase mapping and DTO round trips

    func testFoodDTOEncodesSnakeCaseColumnNames() throws {
        let food = try makeFood(
            "Chicken (with skin)", category: "Protein (Fat)",
            calories: 239, protein: 27.3, carbs: 0, fat: 13.6, fiber: 0,
            barcode: "1234567890123", source: .seed
        )

        let dto = try XCTUnwrap(NutritionFoodDTO(food: food, now: epoch))
        let encoded = try jsonObject(try XCTUnwrap(NutritionSyncCoding.encode(dto)))
        let keys = Set(encoded.keys)

        for expected in [
            "daily_grams", "is_fat", "is_custom", "calories_per_100g",
            "protein_per_100g", "carbs_per_100g", "fat_per_100g", "fiber_per_100g",
            "food_category", "serving_size", "serving_unit", "is_favorite",
            "is_verified", "last_used", "created_at", "updated_at"
        ] {
            XCTAssertTrue(keys.contains(expected), "missing column \(expected)")
        }

        // The old encoder sent Core Data attribute names verbatim. None of those
        // may appear on the wire.
        for forbidden in ["dailyGrams", "isFat", "isCustom", "caloriesPer100g", "createdAt", "updatedAt"] {
            XCTAssertFalse(keys.contains(forbidden), "camelCase key \(forbidden) reached the wire")
        }

        XCTAssertEqual(encoded["calories_per_100g"] as? Double, 239)
        XCTAssertEqual(encoded["source"] as? String, "seed")
        XCTAssertEqual(encoded["category"] as? String, "Protein (Fat)")
    }

    func testMealEntryDTOUsesTheRealColumnNames() throws {
        let food = try makeReferenceFood()
        let entry = try log(food, grams: 150, on: day())
        entry.updatedAt = epoch
        try context.save()

        let dto = try XCTUnwrap(NutritionMealEntryDTO(entry: entry))
        let encoded = try jsonObject(try XCTUnwrap(NutritionSyncCoding.encode(dto)))
        let keys = Set(encoded.keys)

        for expected in ["id", "meal_id", "food_name", "category", "grams_consumed", "calories", "protein", "carbs", "fat", "fiber", "updated_at"] {
            XCTAssertTrue(keys.contains(expected), "missing column \(expected)")
        }

        // The three names the old encoder invented for this table.
        for forbidden in ["name", "quantity_grams", "meal_type"] {
            XCTAssertFalse(keys.contains(forbidden), "\(forbidden) is not a column on eckstein_meal_entries")
        }

        XCTAssertEqual(encoded["grams_consumed"] as? Int, 150)
        XCTAssertEqual(encoded["food_name"] as? String, "Reference")
        // No `created_at`: the entity has none, so the server default applies
        // rather than an invented timestamp.
        XCTAssertFalse(keys.contains("created_at"))
    }

    /// A `nil` component must omit the key rather than send `null` or, worse, a
    /// zero the food never declared.
    func testMissingNutritionOmitsTheKeyRatherThanSendingZero() throws {
        let sparse = try service.upsertFood(from: FoodTemplate(
            name: "Sparse", category: "External", barcode: "9999999999999",
            caloriesPer100g: 400, proteinPer100g: nil, carbsPer100g: nil,
            fatPer100g: nil, fiberPer100g: nil,
            brand: nil, servingSize: nil, servingUnit: nil
        ), source: .barcode)

        XCTAssertNil(sparse.proteinPer100g)
        XCTAssertEqual(sparse.caloriesPer100g?.doubleValue ?? -1, 400, accuracy: 0.0001)

        let dto = try XCTUnwrap(NutritionFoodDTO(food: sparse, now: epoch))
        let keys = Set(try jsonObject(try XCTUnwrap(NutritionSyncCoding.encode(dto))).keys)

        XCTAssertFalse(keys.contains("protein_per_100g"))
        XCTAssertFalse(keys.contains("fiber_per_100g"))
        XCTAssertTrue(keys.contains("calories_per_100g"))
    }

    func testMealDTOReportsTheCachedTotalsRatherThanZero() throws {
        let food = try makeReferenceFood()
        try log(food, grams: 150, on: day(), mealNumber: 1, mealType: .breakfast)

        let meal = try XCTUnwrap(try service.entries(on: day(), calendar: calendar).first?.meal)
        let dto = try XCTUnwrap(NutritionMealDTO(meal: meal, now: epoch))

        XCTAssertEqual(dto.totalCalories, 300)
        XCTAssertEqual(dto.totalProtein, 30, accuracy: 0.0001)
        XCTAssertEqual(dto.totalCarbs, 15, accuracy: 0.0001)
        XCTAssertEqual(dto.totalFat, 7.5, accuracy: 0.0001)
        XCTAssertEqual(dto.mealType, "breakfast")
        XCTAssertEqual(dto.mealNumber, 1)

        let encoded = try jsonObject(try XCTUnwrap(NutritionSyncCoding.encode(dto)))
        XCTAssertNotNil(encoded["total_calories"])
        XCTAssertNotNil(encoded["is_carb_load"])
        // `date` is a Postgres DATE, not an instant.
        XCTAssertEqual((encoded["date"] as? String)?.count, 10)
    }

    func testPreferencesDTOKeepsFatAndFiberGoals() throws {
        try service.setGoals(DailyNutritionGoals(calories: 2200, protein: 180, carbs: 210, fat: 70, fiber: 35))

        let request: NSFetchRequest<CDUserPreferences> = CDUserPreferences.fetchRequest()
        let preferences = try XCTUnwrap(try context.fetch(request).first)
        let dto = try XCTUnwrap(NutritionPreferencesDTO(preferences: preferences))

        XCTAssertEqual(dto.dailyCalorieGoal, 2200)
        XCTAssertEqual(dto.dailyProteinGoal, 180)
        XCTAssertEqual(dto.dailyCarbGoal, 210)
        XCTAssertEqual(dto.dailyFatGoal ?? -1, 70)
        XCTAssertEqual(dto.dailyFiberGoal ?? -1, 35)

        let keys = Set(try jsonObject(try XCTUnwrap(NutritionSyncCoding.encode(dto))).keys)
        for expected in ["daily_calorie_goal", "daily_protein_goal", "daily_carb_goal", "daily_fat_goal", "daily_fiber_goal"] {
            XCTAssertTrue(keys.contains(expected), "missing column \(expected)")
        }
        XCTAssertFalse(keys.contains("dailyCalorieGoal"))
        // A goal the user never set is absent rather than zero.
        XCTAssertFalse(keys.contains("height_cm"))
    }

    func testEveryNutritionDTOEncodesAndDecodesBackToItself() throws {
        let decoder = NutritionSyncCoding.makeDecoder()
        let encoder = NutritionSyncCoding.makeEncoder()

        let food = try makeFood("Round Trip", category: "Nuts", calories: 579, protein: 21.2,
                                carbs: 21.6, fat: 49.9, fiber: 12.5, barcode: "070470003146", source: .api)
        let foodDTO = try XCTUnwrap(NutritionFoodDTO(food: food, now: epoch))
        XCTAssertEqual(try decoder.decode(NutritionFoodDTO.self, from: encoder.encode(foodDTO)), foodDTO)

        let logged = try log(food, grams: 28, on: epoch)
        logged.updatedAt = epoch
        try context.save()
        let entryDTO = try XCTUnwrap(NutritionMealEntryDTO(entry: logged))
        XCTAssertEqual(try decoder.decode(NutritionMealEntryDTO.self, from: encoder.encode(entryDTO)), entryDTO)

        let meal = try XCTUnwrap(logged.meal)
        // `.iso8601` carries no fractional seconds, so a `Date()` here would not
        // survive the round trip.
        meal.updatedAt = epoch
        try context.save()
        let mealDTO = try XCTUnwrap(NutritionMealDTO(meal: meal, now: epoch))
        XCTAssertEqual(try decoder.decode(NutritionMealDTO.self, from: encoder.encode(mealDTO)), mealDTO)

        let preferencesDTO = NutritionPreferencesDTO(
            id: UUID(), userID: nil, dailyCalorieGoal: 2200, dailyProteinGoal: 180,
            dailyCarbGoal: 210, dailyFatGoal: 70, dailyFiberGoal: 35,
            weightUnit: "kg", heightCm: 180, activityLevel: "moderate"
        )
        XCTAssertEqual(try decoder.decode(NutritionPreferencesDTO.self, from: encoder.encode(preferencesDTO)), preferencesDTO)
    }

    /// The two tables that must **not** be sent a `user_id`: owned through their
    /// meal, or shared. Injecting one there is a guaranteed PostgREST failure.
    func testUserIDRequirementMatchesTheSchema() {
        XCTAssertTrue(NutritionSyncTable.requiresUserID(NutritionSyncTable.meals))
        XCTAssertTrue(NutritionSyncTable.requiresUserID(NutritionSyncTable.preferences))

        XCTAssertFalse(NutritionSyncTable.requiresUserID(NutritionSyncTable.foods))
        XCTAssertFalse(NutritionSyncTable.requiresUserID(NutritionSyncTable.mealEntries))
    }

    // MARK: - 20-21. The barcode path

    @MainActor
    func testResolvingABarcodeWritesAnOfficialCatalogRow() async throws {
        let resolver = BarcodeFoodResolver(service: service) { _ in productResponse() }

        let resolved = try await resolver.resolve(barcode: "1234567890123")
        let food = try XCTUnwrap(resolved)

        XCTAssertEqual(food.name, "Scanned Bar")
        XCTAssertEqual(food.barcode, "1234567890123")
        XCTAssertEqual(food.caloriesPer100g?.doubleValue ?? -1, 380, accuracy: 0.0001)
        XCTAssertEqual(food.proteinPer100g?.doubleValue ?? -1, 33, accuracy: 0.0001)
        XCTAssertEqual(food.nutritionSource, .barcode)
        // A catalog row carries an empty `category`, so it never appears in the
        // diet-rule pickers.
        XCTAssertEqual(food.category, "")
    }

    @MainActor
    func testResolvingTheSameBarcodeTwiceReusesTheRow() async throws {
        let resolver = BarcodeFoodResolver(service: service) { _ in productResponse() }

        // `XCTUnwrap` takes an autoclosure, which cannot contain `await`, so the
        // async call is completed into a local first.
        let firstResolved = try await resolver.resolve(barcode: "1234567890123")
        let secondResolved = try await resolver.resolve(barcode: "1234567890123")
        let first = try XCTUnwrap(firstResolved)
        let second = try XCTUnwrap(secondResolved)

        XCTAssertEqual(first.objectID, second.objectID)

        let request: NSFetchRequest<CDEcksteinFood> = CDEcksteinFood.fetchRequest()
        request.predicate = NSPredicate(format: "barcode == %@", "1234567890123")
        XCTAssertEqual(try context.count(for: request), 1)
    }

    /// The second lookup must not even reach the network once the barcode is
    /// already in the catalog.
    @MainActor
    func testAKnownBarcodeNeverTouchesTheNetwork() async throws {
        try makeFood("Local", calories: 100, barcode: "5555555555555")

        let resolver = BarcodeFoodResolver(service: service) { _ in
            throw URLError(.notConnectedToInternet)
        }

        let resolved = try await resolver.resolve(barcode: "5555555555555")
        let food = try XCTUnwrap(resolved)
        XCTAssertEqual(food.name, "Local")
    }

    @MainActor
    func testAnUnknownBarcodeResolvesToNothing() async throws {
        let resolver = BarcodeFoodResolver(service: service) { _ in
            FoodAPIResponse(product: nil, status: 0, statusVerbose: "product not found")
        }

        let resolved = try await resolver.resolve(barcode: "0000000000000")
        XCTAssertNil(resolved)
    }

    /// A product that declares energy but omits a macro keeps the macro unknown.
    /// `?? 0` here would record a claim the label never made.
    @MainActor
    func testAPartiallyLabelledProductKeepsMissingFieldsNil() async throws {
        let resolver = BarcodeFoodResolver(service: service) { _ in
            productResponse(protein: nil, carbs: nil, fiber: nil)
        }

        let resolved = try await resolver.resolve(barcode: "1234567890123")
        let food = try XCTUnwrap(resolved)

        XCTAssertEqual(food.caloriesPer100g?.doubleValue ?? -1, 380, accuracy: 0.0001)
        XCTAssertEqual(food.fatPer100g?.doubleValue ?? -1, 15, accuracy: 0.0001)
        XCTAssertNil(food.proteinPer100g)
        XCTAssertNil(food.carbsPer100g)
        XCTAssertNil(food.fiberPer100g)

        // And nothing downstream invents a zero for them. A food that declares
        // no carbs really does contribute no carbs, so the entry's carb figure is
        // zero — but the *catalog row* stays honest about not knowing.
        let entry = try log(food, grams: 100, on: day())
        XCTAssertEqual(entry.calories?.doubleValue ?? -1, 380, accuracy: 0.0001)
        XCTAssertEqual(entry.fat?.doubleValue ?? -1, 15, accuracy: 0.0001)
        XCTAssertEqual(entry.protein?.doubleValue ?? -1, 0, accuracy: 0.0001)
    }

    /// A product with no declared energy at all is not usable as a food record.
    @MainActor
    func testAProductWithNoUsableDataResolvesToNothing() async throws {
        let resolver = BarcodeFoodResolver(service: service) { _ in
            productResponse(calories: nil)
        }

        let resolved = try await resolver.resolve(barcode: "1234567890123")
        XCTAssertNil(resolved)
    }

    @MainActor
    func testANetworkFailurePropagatesInsteadOfCrashingOrLying() async throws {
        let resolver = BarcodeFoodResolver(service: service) { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await resolver.resolve(barcode: "1234567890123")
            XCTFail("a network failure must not be reported as a successful lookup")
        } catch {
            XCTAssertTrue(error is URLError)
        }

        // Nothing was written on the way out.
        let request: NSFetchRequest<CDEcksteinFood> = CDEcksteinFood.fetchRequest()
        XCTAssertEqual(try context.count(for: request), 0)
    }

    // MARK: - 22 (continued). Diet-rule foods have values without a catalog row

    /// The official Diet UI logs `DietRule` values, not catalog rows. Without the
    /// fixture fallback a diet-rule meal would read as zero calories.
    func testADietRuleWithNoCatalogRowStillGetsASnapshot() throws {
        let rule = try XCTUnwrap(EcksteinDietRules.carbRules.first { $0.foodName == "Rice" })

        let entry = try log(nil, foodName: rule.foodName, category: rule.category.rawValue, grams: 200, on: day())

        XCTAssertNil(entry.food, "no catalog row exists for this rule")
        XCTAssertEqual(entry.calories?.doubleValue ?? -1, 260, accuracy: 0.0001)
        XCTAssertEqual(entry.protein?.doubleValue ?? -1, 5.4, accuracy: 0.0001)
    }

    /// The two snack placeholders have no documented value, so the entry keeps
    /// `nil` — unknown, not a fabricated zero.
    func testAFoodWithNoDocumentedValueKeepsAnUnknownSnapshot() throws {
        let rule = try XCTUnwrap(EcksteinDietRules.snackRules.first)

        let entry = try log(nil, foodName: rule.foodName, category: rule.category.rawValue, grams: 100, on: day())

        XCTAssertFalse(entry.hasNutritionData)
        XCTAssertNil(entry.calories)
        XCTAssertEqual(entry.nutritionSnapshot, .zero)
    }

    // MARK: - Seeding the default catalog

    func testSeedingFillsTheOfficialCatalogWithNutritionAndIsIdempotent() throws {
        let written = try NutritionCatalogSeed.seedIfNeeded(context: context)
        XCTAssertGreaterThan(written, 0)

        let chicken = try XCTUnwrap(try service.food(named: "Chicken Breast (Cooked)", category: ""))
        XCTAssertEqual(chicken.caloriesPer100g?.doubleValue ?? -1, 165, accuracy: 0.0001)
        XCTAssertEqual(chicken.proteinPer100g?.doubleValue ?? -1, 31, accuracy: 0.0001)
        XCTAssertEqual(chicken.nutritionSource, .seed)

        // Every seeded row carries all five values, so no shipped food logs as
        // unknown.
        for food in try service.foods(matching: "") where food.source == NutritionSource.seed.storedValue {
            XCTAssertNotNil(food.caloriesPer100g, "\(food.name ?? "?") has no calories")
            XCTAssertNotNil(food.proteinPer100g, "\(food.name ?? "?") has no protein")
            XCTAssertNotNil(food.carbsPer100g, "\(food.name ?? "?") has no carbs")
            XCTAssertNotNil(food.fatPer100g, "\(food.name ?? "?") has no fat")
            XCTAssertNotNil(food.fiberPer100g, "\(food.name ?? "?") has no fiber")
        }

        // A second launch writes nothing.
        XCTAssertEqual(try NutritionCatalogSeed.seedIfNeeded(context: context), 0)
    }

    /// A store seeded before Phase 3 holds the diet-rule rows with every
    /// nutrition column `NULL`. The backfill fills those and leaves everything
    /// else alone.
    func testBackfillFillsLegacyDietRuleRowsWithoutOverwriting() throws {
        let legacy = try makeFood("Rice", category: "Carbs")
        let corrected = try makeFood("Chicken (with skin)", category: "Protein (Fat)",
                                     calories: 111, protein: 1, carbs: 2, fat: 3, fiber: 4)

        let filled = try NutritionCatalogSeed.backfillDietRuleNutrition(context: context)

        XCTAssertEqual(filled, 1)
        XCTAssertEqual(legacy.caloriesPer100g?.doubleValue ?? -1, 130, accuracy: 0.0001)
        XCTAssertEqual(legacy.nutritionSource, .seed)

        // A row the user had already corrected is not overwritten.
        XCTAssertEqual(corrected.caloriesPer100g?.doubleValue ?? -1, 111, accuracy: 0.0001)
        XCTAssertEqual(corrected.proteinPer100g?.doubleValue ?? -1, 1, accuracy: 0.0001)

        // And re-running writes nothing.
        XCTAssertEqual(try NutritionCatalogSeed.backfillDietRuleNutrition(context: context), 0)
    }

    // MARK: - 25. Rows written before nutrition tracking stay readable

    func testALegacyEntryWithNullNutritionStaysReadable() throws {
        // Built the way a pre-Phase-3 store holds it: values recorded, nutrition
        // columns `NULL`.
        let meal = CDEcksteinMeal(context: context)
        meal.id = UUID()
        meal.date = day()
        meal.mealNumber = 1
        meal.isCarbLoad = false

        let entry = CDEcksteinMealEntry(context: context)
        entry.id = UUID()
        entry.foodName = "Some Old Food"
        entry.category = nil
        entry.gramsConsumed = 250
        entry.meal = meal
        try context.save()

        XCTAssertNil(entry.calories)
        XCTAssertFalse(entry.hasNutritionData)
        XCTAssertEqual(entry.nutritionSnapshot, .zero)

        // It is still returned, still counted, and contributes nothing.
        let entries = try service.entries(on: day(), calendar: calendar)
        XCTAssertEqual(entries.map(\.objectID), [entry.objectID])

        let summary = try service.dailySummary(for: day(), calendar: calendar)
        XCTAssertEqual(summary.entryCount, 1)
        XCTAssertEqual(summary.totals, .zero)

        // The DTO sends it as unknown, not as a zero-calorie meal.
        let dto = try XCTUnwrap(NutritionMealEntryDTO(entry: entry))
        XCTAssertNil(dto.calories)
        XCTAssertFalse(Set(try jsonObject(try XCTUnwrap(NutritionSyncCoding.encode(dto))).keys).contains("calories"))

        // And the export writes nothing for it rather than a fabricated zero.
        let input = try XCTUnwrap(NutritionHealthKitExportInput(entry: entry, fallbackDate: day()))
        XCTAssertTrue(NutritionHealthKitPlanner.samples(for: input).isEmpty)
    }

    // MARK: - 23. HealthKit metadata identifiers

    func testSampleMetadataCarriesAStableEntryIdentifier() throws {
        let entryID = UUID()
        let metadata = NutritionHealthKitMetadata.metadata(entryID: entryID, foodName: "Rice")

        XCTAssertEqual(metadata[NutritionHealthKitMetadata.mealEntryUUIDKey] as? String, entryID.uuidString)
        XCTAssertEqual(metadata[NutritionHealthKitMetadata.sourceAppKey] as? String, "Eckstein")
        XCTAssertEqual(metadata[HKMetadataKeyFoodType] as? String, "Rice")

        XCTAssertEqual(NutritionHealthKitMetadata.entryID(in: metadata), entryID)
        XCTAssertTrue(NutritionHealthKitMetadata.isOurs(metadata))
    }

    /// A sample written by another app, or by a build that predates the key, is
    /// not ours to skip or to delete.
    func testForeignMetadataIsNotMistakenForOurs() {
        XCTAssertNil(NutritionHealthKitMetadata.entryID(in: nil))
        XCTAssertNil(NutritionHealthKitMetadata.entryID(in: [:]))
        XCTAssertNil(NutritionHealthKitMetadata.entryID(in: [NutritionHealthKitMetadata.mealEntryUUIDKey: "not-a-uuid"]))
        XCTAssertFalse(NutritionHealthKitMetadata.isOurs(nil))
        XCTAssertFalse(NutritionHealthKitMetadata.isOurs([NutritionHealthKitMetadata.sourceAppKey: "OtherApp"]))
    }

    func testEveryNutrientMapsToItsHealthKitIdentifierAndUnit() {
        for nutrient in NutritionHealthKitNutrient.allCases {
            XCTAssertNotNil(nutrient.quantityTypeIdentifier, "\(nutrient.rawValue) has no identifier")
            XCTAssertNotNil(nutrient.quantityType, "\(nutrient.rawValue) has no quantity type")
        }

        XCTAssertEqual(NutritionHealthKitNutrient.energyConsumed.unit, .kilocalorie())
        XCTAssertEqual(NutritionHealthKitNutrient.protein.unit, .gram())

        let snapshot = NutritionSnapshot(calories: 300, protein: 30, carbs: 15, fat: 7.5, fiber: 3)
        XCTAssertEqual(NutritionHealthKitNutrient.energyConsumed.value(in: snapshot), 300)
        XCTAssertEqual(NutritionHealthKitNutrient.fatTotal.value(in: snapshot), 7.5)
        XCTAssertEqual(NutritionHealthKitNutrient.fiber.value(in: snapshot), 3)
    }

    // MARK: - 24. HealthKit dedupe

    func testPlannerSkipsZeroAndUnknownNutrients() {
        let entryID = UUID()

        let full = NutritionHealthKitExportInput(
            entryID: entryID, foodName: "Reference", date: day(),
            snapshot: NutritionSnapshot(calories: 300, protein: 30, carbs: 15, fat: 7.5, fiber: 3),
            hasNutritionData: true
        )
        XCTAssertEqual(NutritionHealthKitPlanner.samples(for: full).count, 5)

        // A zero contributes nothing to a daily sum and is indistinguishable from
        // a real measurement of zero, so it is not written.
        let noFiber = NutritionHealthKitExportInput(
            entryID: entryID, foodName: "Chicken", date: day(),
            snapshot: NutritionSnapshot(calories: 165, protein: 31, carbs: 0, fat: 3.6, fiber: 0),
            hasNutritionData: true
        )
        XCTAssertEqual(NutritionHealthKitPlanner.samples(for: noFiber).map(\.nutrient),
                       [.energyConsumed, .protein, .fatTotal])

        // No recorded nutrition at all writes nothing.
        let unknown = NutritionHealthKitExportInput(
            entryID: entryID, foodName: "Legacy", date: day(),
            snapshot: .zero, hasNutritionData: false
        )
        XCTAssertTrue(NutritionHealthKitPlanner.samples(for: unknown).isEmpty)
    }

    func testDedupeKeyIsTheEntryAndNutrientPair() {
        let first = UUID()
        let second = UUID()
        let input = NutritionHealthKitExportInput(
            entryID: first, foodName: "Reference", date: day(),
            snapshot: NutritionSnapshot(calories: 300, protein: 30, carbs: 15, fat: 7.5, fiber: 3),
            hasNutritionData: true
        )

        let alreadyWritten: Set<NutritionHealthKitSampleKey> = [
            NutritionHealthKitSampleKey(entryID: first, nutrient: .energyConsumed),
            NutritionHealthKitSampleKey(entryID: first, nutrient: .protein)
        ]

        // An interrupted export resumes at the first missing sample…
        XCTAssertEqual(
            NutritionHealthKitPlanner.missingSamples(for: [input], alreadyWritten: alreadyWritten).map(\.nutrient),
            [.carbohydrates, .fatTotal, .fiber]
        )
        XCTAssertFalse(NutritionHealthKitPlanner.isFullyExported(input, alreadyWritten: alreadyWritten))

        // …and a complete one is a no-op.
        let complete = Set(NutritionHealthKitNutrient.allCases.map {
            NutritionHealthKitSampleKey(entryID: first, nutrient: $0)
        })
        XCTAssertTrue(NutritionHealthKitPlanner.missingSamples(for: [input], alreadyWritten: complete).isEmpty)

        // The key is the pair: another entry's energy sample does not cover this one.
        let otherEntry = Set(NutritionHealthKitNutrient.allCases.map {
            NutritionHealthKitSampleKey(entryID: second, nutrient: $0)
        })
        XCTAssertEqual(NutritionHealthKitPlanner.missingSamples(for: [input], alreadyWritten: otherEntry).count, 5)
    }

    // MARK: - The export, against a stand-in store

    @MainActor
    func testExportingADayWritesOnceAndThenWritesNothing() async throws {
        let food = try makeReferenceFood()
        try log(food, grams: 150, on: day(), mealNumber: 1, mealType: .breakfast)

        let store = MockNutritionHealthKitStore()
        let exporter = NutritionHealthKitService(store: store)

        let first = await exporter.exportDay(day(), service: service, calendar: calendar)
        XCTAssertEqual(first.written, 5)
        XCTAssertEqual(first.failed, 0)
        XCTAssertTrue(first.isAuthorized)
        XCTAssertTrue(first.didWrite)
        XCTAssertEqual(store.written.count, 5)

        // Re-exporting the same day writes nothing: the samples are already there.
        let second = await exporter.exportDay(day(), service: service, calendar: calendar)
        XCTAssertEqual(second.written, 0)
        XCTAssertEqual(second.skipped, 5)
        XCTAssertTrue(second.wasAlreadyUpToDate)
        XCTAssertEqual(store.written.count, 5, "no duplicate sample was written")
    }

    @MainActor
    func testExportResumesAtTheFirstMissingNutrient() async throws {
        let food = try makeReferenceFood()
        let entry = try log(food, grams: 150, on: day())
        let entryID = try XCTUnwrap(entry.id)

        // A previous run stopped after calories and protein.
        let store = MockNutritionHealthKitStore()
        store.preseeded = [
            NutritionHealthKitSampleKey(entryID: entryID, nutrient: .energyConsumed),
            NutritionHealthKitSampleKey(entryID: entryID, nutrient: .protein)
        ]

        let result = await NutritionHealthKitService(store: store)
            .exportDay(day(), service: service, calendar: calendar)

        XCTAssertEqual(result.written, 3)
        XCTAssertEqual(result.skipped, 2)
        XCTAssertEqual(Set(store.written.map(\.nutrient)), Set([.carbohydrates, .fatTotal, .fiber]))
    }

    @MainActor
    func testADeniedPermissionWritesNothingAndDoesNotCrash() async throws {
        let food = try makeReferenceFood()
        try log(food, grams: 150, on: day())

        let store = MockNutritionHealthKitStore()
        store.authorizationGranted = false

        let result = await NutritionHealthKitService(store: store)
            .exportDay(day(), service: service, calendar: calendar)

        XCTAssertFalse(result.isAuthorized)
        XCTAssertEqual(result.written, 0)
        XCTAssertTrue(store.written.isEmpty)
    }

    @MainActor
    func testADeviceWithoutHealthKitWritesNothing() async throws {
        let food = try makeReferenceFood()
        try log(food, grams: 150, on: day())

        let store = MockNutritionHealthKitStore()
        store.isHealthDataAvailable = false

        let result = await NutritionHealthKitService(store: store)
            .exportDay(day(), service: service, calendar: calendar)

        XCTAssertFalse(result.isAvailable)
        XCTAssertFalse(result.didWrite)
        XCTAssertEqual(store.authorizationRequests, 0, "no permission prompt on a device without HealthKit")
    }

    /// One sample failing must not abandon the rest of the day.
    @MainActor
    func testAFailedSampleDoesNotStopTheOthers() async throws {
        let food = try makeReferenceFood()
        try log(food, grams: 150, on: day())

        let store = MockNutritionHealthKitStore()
        store.failingNutrients = [.protein]

        let result = await NutritionHealthKitService(store: store)
            .exportDay(day(), service: service, calendar: calendar)

        XCTAssertEqual(result.written, 4)
        XCTAssertEqual(result.failed, 1)
        XCTAssertFalse(store.written.contains { $0.nutrient == .protein })
    }

    /// An entry logged before nutrition tracking is counted, not written.
    @MainActor
    func testAnEntryWithoutNutritionIsReportedRatherThanExportedAsZeros() async throws {
        let meal = CDEcksteinMeal(context: context)
        meal.id = UUID()
        meal.date = day()
        meal.mealNumber = 1
        meal.isCarbLoad = false

        let legacy = CDEcksteinMealEntry(context: context)
        legacy.id = UUID()
        legacy.foodName = "Some Old Food"
        legacy.gramsConsumed = 250
        legacy.meal = meal
        try context.save()

        let store = MockNutritionHealthKitStore()
        let result = await NutritionHealthKitService(store: store)
            .exportDay(day(), service: service, calendar: calendar)

        XCTAssertEqual(result.written, 0)
        XCTAssertEqual(result.entriesWithoutNutrition, 1)
        XCTAssertTrue(store.written.isEmpty)
    }
}

// MARK: - Stand-in store

/// An in-memory `NutritionHealthKitStore`.
///
/// It exists because a test cannot grant HealthKit write permission and the
/// simulator has no user data — not because the shipped `HealthKitNutritionStore`
/// is untestable itself. The real store is untouched and remains the only
/// implementation the app uses.
@MainActor
final class MockNutritionHealthKitStore: NutritionHealthKitStore {

    var isHealthDataAvailable: Bool = true
    var authorizationGranted: Bool = true

    /// Samples that were already in HealthKit before this test ran.
    var preseeded: Set<NutritionHealthKitSampleKey> = []

    /// Nutrients whose write should fail, to exercise the partial-failure path.
    var failingNutrients: Set<NutritionHealthKitNutrient> = []

    private(set) var written: [NutritionHealthKitSamplePlan] = []
    private(set) var authorizationRequests = 0

    func requestWriteAuthorization() async -> Bool {
        authorizationRequests += 1
        return authorizationGranted
    }

    /// Read back from what was written, the way the real store reads back from
    /// HealthKit, so a second export sees its own samples.
    func recordedNutrients(for entryID: UUID) async -> Set<NutritionHealthKitNutrient> {
        var recorded = Set(preseeded.filter { $0.entryID == entryID }.map(\.nutrient))
        recorded.formUnion(written.filter { $0.entryID == entryID }.map(\.nutrient))
        return recorded
    }

    func write(_ plan: NutritionHealthKitSamplePlan) async throws {
        if failingNutrients.contains(plan.nutrient) {
            throw MockNutritionHealthKitError.writeFailed
        }
        written.append(plan)
    }
}

enum MockNutritionHealthKitError: Error {
    case writeFailed
}
