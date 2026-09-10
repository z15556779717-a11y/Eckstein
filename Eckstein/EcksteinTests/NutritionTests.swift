//
//  NutritionTests.swift
//  EcksteinTests
//
//  Created by Eliad Shahar on 10/09/2026.
//

import XCTest
import CoreData
@testable import Eckstein

/// Tests for the official nutrition layer: `NutritionService`,
/// `NutritionAggregator`, `NutritionSnapshot`, `MealType` and the `"Eckstein 2"`
/// Core Data model version.
///
/// These cover the thirteen cases NUTRITION_MIGRATION_PLAN.md §14 requires,
/// plus the day-boundary and goal round-trips the plan calls out in §7 and §8.
///
/// Every test runs against an in-memory store built from the *current* compiled
/// model, so they also fail if the model version or its optionals regress.
class NutritionTests: XCTestCase {
    var controller: PersistenceController!
    var context: NSManagedObjectContext!
    var service: NutritionService!

    /// A fixed calendar so a test never depends on the machine's time zone.
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

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

    /// Midday on the day `daysAgo` days before today.
    ///
    /// Midday rather than midnight: the assertions below are about which *day* an
    /// entry lands on, and noon is maximally far from the boundary in any time zone.
    private func day(_ daysAgo: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        let shifted = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        return calendar.date(byAdding: .hour, value: 12, to: shifted) ?? shifted
    }

    /// A catalog food with declared per-100 g values.
    @discardableResult
    private func makeFood(
        _ name: String,
        category: String = "",
        calories: Double?,
        protein: Double? = nil,
        carbs: Double? = nil,
        fat: Double? = nil,
        fiber: Double? = nil,
        barcode: String? = nil
    ) throws -> CDEcksteinFood {
        let food = CDEcksteinFood(context: context)
        food.id = UUID()
        food.name = name
        food.category = category
        food.dailyGrams = 0
        food.isCustom = false
        food.createdAt = Date()
        food.caloriesPer100g = calories.map { NSNumber(value: $0) }
        food.proteinPer100g = protein.map { NSNumber(value: $0) }
        food.carbsPer100g = carbs.map { NSNumber(value: $0) }
        food.fatPer100g = fat.map { NSNumber(value: $0) }
        food.fiberPer100g = fiber.map { NSNumber(value: $0) }
        food.barcode = barcode
        food.foodCategory = "Test"
        try context.save()
        return food
    }

    /// 200 kcal / 20 g protein / 10 g carbs / 5 g fat / 2 g fiber per 100 g.
    /// 150 g of it is 300 kcal / 30 / 15 / 7.5 / 3.
    private func makeReferenceFood(_ name: String = "Reference") throws -> CDEcksteinFood {
        try makeFood(name, calories: 200, protein: 20, carbs: 10, fat: 5, fiber: 2)
    }

    @discardableResult
    private func log(
        _ food: CDEcksteinFood,
        grams: Double,
        on date: Date,
        mealNumber: Int32 = 1,
        mealType: MealType? = nil
    ) throws -> CDEcksteinMealEntry {
        try service.logEntry(
            foodName: food.name ?? "",
            category: food.category,
            grams: grams,
            mealNumber: mealNumber,
            mealType: mealType,
            date: date,
            food: food,
            calendar: calendar
        )
    }

    // MARK: - 1-5. Daily aggregation of each required value

    func testDailyCaloriesAggregation() throws {
        let food = try makeReferenceFood()
        let today = day(0)

        try log(food, grams: 150, on: today)   // 300 kcal
        try log(food, grams: 50, on: today)    // merges into the same entry: 200 g

        // 200 g of a 200 kcal/100 g food.
        XCTAssertEqual(try service.summary(on: today, calendar: calendar).dailyCalories,
                       400, accuracy: 0.0001)
    }

    func testDailyProteinAggregation() throws {
        let food = try makeReferenceFood()
        let eggs = try makeFood("Eggs", calories: 155, protein: 13, carbs: 1.1, fat: 11, fiber: 0)
        let today = day(0)

        try log(food, grams: 100, on: today)   // 20 g
        try log(eggs, grams: 100, on: today)   // 13 g

        XCTAssertEqual(try service.summary(on: today, calendar: calendar).dailyProtein,
                       33, accuracy: 0.0001)
    }

    func testDailyCarbohydrateAggregation() throws {
        let food = try makeReferenceFood()
        let rice = try makeFood("Rice", calories: 130, protein: 2.7, carbs: 28.2, fat: 0.3, fiber: 0.4)
        let today = day(0)

        try log(food, grams: 100, on: today)   // 10 g
        try log(rice, grams: 100, on: today)   // 28.2 g

        XCTAssertEqual(try service.summary(on: today, calendar: calendar).dailyCarbohydrates,
                       38.2, accuracy: 0.0001)
    }

    func testDailyFatAggregation() throws {
        let food = try makeReferenceFood()
        let today = day(0)

        try log(food, grams: 100, on: today)   // 5 g
        try log(food, grams: 50, on: today)    // merges: 150 g -> 7.5 g

        XCTAssertEqual(try service.summary(on: today, calendar: calendar).dailyFat,
                       7.5, accuracy: 0.0001)
    }

    func testDailyFiberAggregation() throws {
        let food = try makeReferenceFood()
        let oats = try makeFood("Oats", calories: 389, protein: 16.9, carbs: 66.3, fat: 6.9, fiber: 10.6)
        let today = day(0)

        try log(food, grams: 100, on: today)   // 2 g
        try log(oats, grams: 50, on: today)    // 5.3 g

        XCTAssertEqual(try service.summary(on: today, calendar: calendar).dailyFiber,
                       7.3, accuracy: 0.0001)
    }

    // MARK: - 6. Meal type filtering

    func testMealTypeFiltering() throws {
        let food = try makeReferenceFood()
        let today = day(0)

        // Meal 1 is breakfast, meal 2 is dinner: the slot lives on the meal, and
        // `findOrCreateMeal` records it on first use.
        try log(food, grams: 100, on: today, mealNumber: 1, mealType: .breakfast)
        try log(food, grams: 200, on: today, mealNumber: 2, mealType: .dinner)

        let summary = try service.summary(on: today, calendar: calendar)

        XCTAssertEqual(summary.byMealType[.breakfast]?.calories ?? -1, 200, accuracy: 0.0001)
        XCTAssertEqual(summary.byMealType[.dinner]?.calories ?? -1, 400, accuracy: 0.0001)
        XCTAssertEqual(summary.byMealType[.lunch]?.calories ?? -1, 0, accuracy: 0.0001)
        XCTAssertEqual(summary.byMealType[.snack]?.calories ?? -1, 0, accuracy: 0.0001)
        XCTAssertEqual(summary.byMealType[.unspecified]?.calories ?? -1, 0, accuracy: 0.0001)

        let meals = try service.recentMeals(limit: 10, through: today, calendar: calendar)
        XCTAssertEqual(Set(meals.map(\.mealType)), [.breakfast, .dinner])
    }

    func testEntriesWithNoRecordedSlotFallIntoUnspecified() throws {
        let food = try makeReferenceFood()
        let today = day(0)

        // No `mealType` passed: the Eckstein two-meal UI has no slot to offer, so
        // the entry must land in the bucket rather than have one guessed.
        let entry = try log(food, grams: 100, on: today, mealNumber: 1)

        XCTAssertNil(entry.meal?.mealType)
        let summary = try service.summary(on: today, calendar: calendar)
        XCTAssertEqual(summary.byMealType[.unspecified]?.calories ?? -1, 200, accuracy: 0.0001)
    }

    // MARK: - 7. Multiple meals in one day

    func testMultipleMealsInTheSameDay() throws {
        let food = try makeReferenceFood()
        let cheese = try makeFood("Cheese", calories: 98, protein: 11.1, carbs: 3.4, fat: 4.3, fiber: 0)
        let today = day(0)

        try log(food, grams: 100, on: today, mealNumber: 1, mealType: .breakfast)
        try log(cheese, grams: 100, on: today, mealNumber: 2, mealType: .lunch)
        try log(cheese, grams: 100, on: today, mealNumber: 2, mealType: .lunch) // merges: 200 g

        let summary = try service.summary(on: today, calendar: calendar)

        XCTAssertEqual(summary.entryCount, 2, "one entry per food per meal")
        XCTAssertEqual(summary.dailyCalories, 200 + 196, accuracy: 0.0001)

        // Two meals were created, not three, and the totals cached on each match
        // the entries they hold.
        let meals = try service.entries(on: today, calendar: calendar).compactMap(\.meal)
        XCTAssertEqual(Set(meals.map(\.objectID)).count, 2)
        for meal in Set(meals) {
            let fromEntries = meal.entriesArray.reduce(NutritionSnapshot.zero) { $0 + $1.nutritionSnapshot }
            XCTAssertEqual(meal.totalCalories?.doubleValue ?? -1, fromEntries.calories, accuracy: 0.0001)
            XCTAssertEqual(meal.totalFiber?.doubleValue ?? -1, fromEntries.fiber, accuracy: 0.0001)
        }
    }

    // MARK: - 8. Different days are isolated

    func testDifferentDaysAreIsolated() throws {
        let food = try makeReferenceFood()
        let today = day(0)
        let yesterday = day(1)

        try log(food, grams: 100, on: today)       // 200 kcal today
        try log(food, grams: 300, on: yesterday)   // 600 kcal yesterday

        let todaySummary = try service.summary(on: today, calendar: calendar)
        let yesterdaySummary = try service.summary(on: yesterday, calendar: calendar)

        XCTAssertEqual(todaySummary.dailyCalories, 200, accuracy: 0.0001)
        XCTAssertEqual(yesterdaySummary.dailyCalories, 600, accuracy: 0.0001)
        XCTAssertEqual(todaySummary.entryCount, 1)
        XCTAssertEqual(yesterdaySummary.entryCount, 1)

        // A seven-day window returns both days, in chronological order.
        let week = try service.summaries(endingOn: today, days: 7, calendar: calendar)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.suffix(2).map(\.dailyCalories), [600, 200])
    }

    func testDayBoundsAreHalfOpen() throws {
        // 00:00 tomorrow belongs to tomorrow, not to today — the reason the
        // predicate upper bound is exclusive.
        let today = day(0)
        let midnightTomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: today)
        )!

        let bounds = NutritionAggregator.dayBounds(containing: today, calendar: calendar)
        XCTAssertTrue(NutritionAggregator.isDate(today, inDayStartingAt: bounds.start, calendar: calendar))
        XCTAssertFalse(
            NutritionAggregator.isDate(midnightTomorrow, inDayStartingAt: bounds.start, calendar: calendar)
        )

        let food = try makeReferenceFood()
        try log(food, grams: 100, on: midnightTomorrow)

        XCTAssertEqual(try service.summary(on: today, calendar: calendar).entryCount, 0)
        XCTAssertEqual(try service.summary(on: midnightTomorrow, calendar: calendar).entryCount, 1)
    }

    // MARK: - 9. An empty day

    func testEmptyDayAggregatesToZero() throws {
        let summary = try service.summary(on: day(3), calendar: calendar)

        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.entryCount, 0)
        XCTAssertEqual(summary.totals, NutritionSnapshot.zero)
        XCTAssertEqual(summary.dailyCalories, 0)
        XCTAssertEqual(summary.dailyProtein, 0)
        XCTAssertEqual(summary.dailyCarbohydrates, 0)
        XCTAssertEqual(summary.dailyFat, 0)
        XCTAssertEqual(summary.dailyFiber, 0)

        // The aggregator is pure, so an empty input behaves the same way with no
        // store involved at all.
        let pure = NutritionAggregator.summary(for: [], on: day(3), calendar: calendar)
        XCTAssertTrue(pure.isEmpty)
        XCTAssertTrue(pure.totals.isZero)
    }

    // MARK: - 10. Historical snapshots do not move

    func testHistoricalEntryKeepsItsNutritionSnapshot() throws {
        let food = try makeReferenceFood("Editable")
        let today = day(0)

        let entry = try log(food, grams: 100, on: today)
        XCTAssertEqual(entry.calories?.doubleValue ?? -1, 200, accuracy: 0.0001)
        XCTAssertEqual(entry.fiber?.doubleValue ?? -1, 2, accuracy: 0.0001)
        XCTAssertTrue(entry.hasNutritionData)

        // The catalog row is corrected afterwards — a user fixing a mistake, or a
        // product being reformulated. History must not silently rewrite itself.
        food.caloriesPer100g = NSNumber(value: 900)
        food.proteinPer100g = NSNumber(value: 90)
        food.fiberPer100g = NSNumber(value: 30)
        try context.save()

        let refetched = try XCTUnwrap(
            try service.entries(on: today, calendar: calendar).first
        )
        XCTAssertEqual(refetched.calories?.doubleValue ?? -1, 200, accuracy: 0.0001)
        XCTAssertEqual(refetched.protein?.doubleValue ?? -1, 20, accuracy: 0.0001)
        XCTAssertEqual(refetched.fiber?.doubleValue ?? -1, 2, accuracy: 0.0001)
        XCTAssertEqual(try service.summary(on: today, calendar: calendar).dailyCalories,
                       200, accuracy: 0.0001)

        // A *new* entry from the same corrected food does pick the new values up.
        let fresh = try log(food, grams: 100, on: day(1))
        XCTAssertEqual(fresh.calories?.doubleValue ?? -1, 900, accuracy: 0.0001)
    }

    // MARK: - 11. Migration compatibility of the model version

    func testCurrentModelVersionCarriesNutritionAndMigratesLightweightly() throws {
        let model = PersistenceController.managedObjectModel

        let expectedFoodAttributes = [
            "barcode", "brand", "caloriesPer100g", "proteinPer100g", "carbsPer100g",
            "fatPer100g", "fiberPer100g", "servingSize", "servingUnit", "foodCategory",
            "isFavorite", "isVerified", "lastUsed", "updatedAt", "source"
        ]
        let food = try XCTUnwrap(model.entitiesByName["CDEcksteinFood"])
        for name in expectedFoodAttributes {
            XCTAssertNotNil(food.attributesByName[name], "CDEcksteinFood.\(name) is missing")
        }

        let entry = try XCTUnwrap(model.entitiesByName["CDEcksteinMealEntry"])
        for name in ["calories", "protein", "carbs", "fat", "fiber", "updatedAt"] {
            XCTAssertNotNil(entry.attributesByName[name], "CDEcksteinMealEntry.\(name) is missing")
        }
        XCTAssertNotNil(entry.relationshipsByName["food"])

        let meal = try XCTUnwrap(model.entitiesByName["CDEcksteinMeal"])
        for name in ["mealType", "totalCalories", "totalProtein", "totalCarbs", "totalFat", "totalFiber"] {
            XCTAssertNotNil(meal.attributesByName[name], "CDEcksteinMeal.\(name) is missing")
        }

        let preferences = try XCTUnwrap(model.entitiesByName["CDUserPreferences"])
        XCTAssertNotNil(preferences.attributesByName["dailyFatGoal"])
        XCTAssertNotNil(preferences.attributesByName["dailyFiberGoal"])

        // Every attribute added by "Eckstein 2" must be optional or defaulted.
        // A non-optional attribute with no default cannot be inferred during a
        // lightweight migration of a populated store, and `usedWithCloudKit`
        // rejects it outright.
        for (entity, names) in [
            (food, expectedFoodAttributes),
            (entry, ["calories", "protein", "carbs", "fat", "fiber", "updatedAt"])
        ] {
            for name in names {
                let attribute = try XCTUnwrap(entity.attributesByName[name])
                XCTAssertTrue(
                    attribute.isOptional || attribute.defaultValue != nil,
                    "\(entity.name ?? "?").\(name) needs a default to stay migratable"
                )
            }
        }

        // The previously shipped version has to remain in the compiled model
        // bundle: Core Data looks up a store's recorded model hash there, so
        // deleting it would leave every existing install unable to open.
        let momdURL = try XCTUnwrap(
            Bundle.main.url(forResource: "Eckstein", withExtension: "momd"),
            "the compiled model bundle is missing"
        )
        let versions = try FileManager.default.contentsOfDirectory(atPath: momdURL.path)
        XCTAssertTrue(versions.contains("Eckstein.mom"), "the pre-migration version is gone: \(versions)")
        XCTAssertTrue(versions.contains("Eckstein 2.mom"), "the current version is missing: \(versions)")

        // Migration must be automatic and inferred, not manual.
        let description = try XCTUnwrap(
            PersistenceController(inMemory: true).container.persistentStoreDescriptions.first
        )
        XCTAssertEqual(
            description.options[NSMigratePersistentStoresAutomaticallyOption] as? Bool, true
        )
        XCTAssertEqual(
            description.options[NSInferMappingModelAutomaticallyOption] as? Bool, true
        )
    }

    // MARK: - 12. Rows written before the migration stay readable

    func testPreMigrationFoodRowsStayReadable() throws {
        // A row exactly as the pre-"Eckstein 2" schema would have written it: no
        // nutrition columns at all.
        let legacy = CDEcksteinFood(context: context)
        legacy.id = UUID()
        legacy.name = "Chicken (with skin)"
        legacy.category = "Protein"
        legacy.dailyGrams = 240
        legacy.isFat = true
        legacy.isCustom = true
        legacy.createdAt = Date()
        try context.save()

        let fetched = try XCTUnwrap(service.food(named: "Chicken (with skin)", category: "Protein"))
        XCTAssertEqual(fetched.dailyGrams, 240)
        XCTAssertTrue(fetched.isFat)
        XCTAssertTrue(fetched.isCustom)
        XCTAssertNil(fetched.caloriesPer100g, "an old row must read back as unknown, not zero")
        XCTAssertNil(fetched.barcode)
        XCTAssertFalse(fetched.isFavorite)
        XCTAssertNil(service.nutrition(for: fetched, grams: 240))

        // Logging it produces an entry with no snapshot — "unknown" — and the day
        // stays summable rather than being corrupted by invented numbers.
        let entry = try log(fetched, grams: 240, on: day(0))
        XCTAssertFalse(entry.hasNutritionData)
        XCTAssertNil(entry.calories)

        let summary = try service.summary(on: day(0), calendar: calendar)
        XCTAssertEqual(summary.entryCount, 1, "the entry itself is still recorded")
        XCTAssertFalse(summary.isEmpty)
        XCTAssertEqual(summary.dailyCalories, 0)
    }

    // MARK: - 13. New fields default to unknown

    func testNewNutritionFieldsDefaultToUnknown() throws {
        let food = CDEcksteinFood(context: context)
        food.id = UUID()
        food.name = "Untouched"
        food.category = ""
        food.dailyGrams = 0
        food.isCustom = false
        food.createdAt = Date()

        let meal = CDEcksteinMeal(context: context)
        meal.id = UUID()
        meal.date = Date()
        meal.mealNumber = 1
        meal.isCarbLoad = false

        let entry = CDEcksteinMealEntry(context: context)
        entry.id = UUID()
        entry.foodName = "Untouched"
        entry.category = ""
        entry.gramsConsumed = 100

        let preferences = CDUserPreferences(context: context)
        preferences.id = UUID()
        preferences.dailyCalorieGoal = 2000
        preferences.dailyProteinGoal = 150
        preferences.dailyCarbGoal = 250

        try context.save()

        // Food: unknowns are nil, booleans fall to false rather than an invented true.
        XCTAssertNil(food.caloriesPer100g)
        XCTAssertNil(food.proteinPer100g)
        XCTAssertNil(food.carbsPer100g)
        XCTAssertNil(food.fatPer100g)
        XCTAssertNil(food.fiberPer100g)
        XCTAssertNil(food.barcode)
        XCTAssertNil(food.brand)
        XCTAssertNil(food.servingSize)
        XCTAssertNil(food.servingUnit)
        XCTAssertNil(food.foodCategory)
        XCTAssertNil(food.lastUsed)
        XCTAssertNil(food.updatedAt)
        XCTAssertNil(food.source)
        XCTAssertFalse(food.isFavorite)
        XCTAssertFalse(food.isVerified)
        XCTAssertEqual(food.entries?.count ?? 0, 0)

        // Meal: no slot recorded, no totals cached, entries relationship empty.
        XCTAssertNil(meal.mealType)
        XCTAssertNil(meal.totalCalories)
        XCTAssertNil(meal.totalProtein)
        XCTAssertNil(meal.totalCarbs)
        XCTAssertNil(meal.totalFat)
        XCTAssertNil(meal.totalFiber)
        XCTAssertNil(meal.updatedAt)
        XCTAssertTrue(meal.entriesArray.isEmpty)

        // Entry: unknown nutrition, no link to a catalog food.
        XCTAssertFalse(entry.hasNutritionData)
        XCTAssertNil(entry.updatedAt)
        XCTAssertNil(entry.food)
        XCTAssertEqual(entry.nutritionSnapshot, .zero)

        // Preferences: the two goals added in this phase are unset — distinct
        // from a goal of zero.
        XCTAssertNil(preferences.dailyFatGoal)
        XCTAssertNil(preferences.dailyFiberGoal)
        XCTAssertEqual(try service.goals(), DailyNutritionGoals(
            calories: 2000, protein: 150, carbs: 250, fat: nil, fiber: nil
        ))

        // A missing preferences row yields `.unset` rather than creating one.
        let emptyStore = PersistenceController(inMemory: true)
        let emptyService = NutritionService(context: emptyStore.container.viewContext)
        XCTAssertEqual(try emptyService.goals(), .unset)
    }

    // MARK: - Meal type vocabulary

    func testMealTypeDecodingNeverThrowsAwayData() {
        XCTAssertEqual(MealType(storedValue: "breakfast"), .breakfast)
        XCTAssertEqual(MealType(storedValue: "DINNER"), .dinner)
        XCTAssertEqual(MealType(storedValue: " Snack "), .snack)

        // Anything else is bucketed, never dropped and never fatal.
        XCTAssertEqual(MealType(storedValue: nil), .unspecified)
        XCTAssertEqual(MealType(storedValue: ""), .unspecified)
        XCTAssertEqual(MealType(storedValue: "brunch"), .unspecified)
        XCTAssertEqual(MealType(storedValue: "unspecified"), .unspecified)

        // And a stored value round-trips, with "no slot" staying nil rather than
        // becoming the literal string "unspecified".
        for meal in MealType.selectableCases {
            XCTAssertEqual(MealType(storedValue: meal.storedValue), meal)
            XCTAssertNotNil(meal.storedValue)
        }
        XCTAssertNil(MealType.unspecified.storedValue)
        XCTAssertFalse(MealType.selectableCases.contains(.unspecified))
    }

    // MARK: - Goals round-trip

    func testGoalsRoundTrip() throws {
        try service.setGoals(DailyNutritionGoals(
            calories: 2200.4, protein: 160.6, carbs: 240, fat: 70, fiber: 30
        ))

        let goals = try service.goals()
        XCTAssertEqual(goals.calories ?? -1, 2200, accuracy: 0.0001, "Int32 goals round rather than truncate")
        XCTAssertEqual(goals.protein ?? -1, 161, accuracy: 0.0001)
        XCTAssertEqual(goals.carbs ?? -1, 240, accuracy: 0.0001)
        XCTAssertEqual(goals.fat ?? -1, 70, accuracy: 0.0001)
        XCTAssertEqual(goals.fiber ?? -1, 30, accuracy: 0.0001)

        // Setting again updates the same row instead of adding a second one.
        try service.setGoals(DailyNutritionGoals(calories: 1800))
        XCTAssertEqual(try context.count(for: CDUserPreferences.fetchRequest()), 1)
        XCTAssertEqual(try service.goals().calories ?? -1, 1800, accuracy: 0.0001)
    }

    // MARK: - Barcode seam

    func testCatalogUpsertMatchesOnBarcodeAndKeepsOneRow() throws {
        let template = FoodTemplate(
            name: "Scanned Yogurt",
            category: "External",
            barcode: "7290000000001",
            caloriesPer100g: 59,
            proteinPer100g: 10,
            carbsPer100g: 3.6,
            fatPer100g: 0.4,
            fiberPer100g: 0,
            brand: "Test Brand",
            servingSize: nil,
            servingUnit: nil
        )

        let first = try service.upsertFood(from: template, source: "barcode")
        let second = try service.upsertFood(from: template, source: "barcode")

        XCTAssertEqual(first.objectID, second.objectID, "scanning twice must not duplicate the row")
        XCTAssertEqual(try context.count(for: CDEcksteinFood.fetchRequest()), 1)
        XCTAssertEqual(first.barcode, "7290000000001")
        XCTAssertEqual(first.source, "barcode")

        // Catalog rows carry an empty `category`, so they never surface in the
        // Eckstein diet-rule pickers.
        XCTAssertEqual(first.category, "")
        XCTAssertEqual(first.foodCategory, "External")

        // The seam the scanner resolves through.
        XCTAssertEqual(try service.food(matchingBarcode: "7290000000001")?.objectID, first.objectID)
        XCTAssertNil(try service.food(matchingBarcode: "  "))
    }
}
