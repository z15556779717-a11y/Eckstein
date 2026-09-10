//
//  DietTests.swift
//  EcksteinTests
//
//  Created by Eliad Shahar on 13/07/2025.
//

import XCTest
import CoreData
@testable import Eckstein

/// Tests for the diet data model and `DietRepository`.
///
/// NOTE (phase-1 audit): this file previously exercised an API that does not
/// exist in the app sources (`createFood(name:brand:calories:protein:carbs:
/// fats:servingSize:servingUnit:)`, `searchFoods(query:)`, `createMeal(type:)`
/// taking a `MealType`, `CDMeal.totalCalories` / `.totalProtein` /
/// `.totalCarbs` / `.totalFats`, `CalorieBankManager(context:)` — its `init`
/// is private — with `deposit(calories:reason:)` / `currentBalance()` /
/// `getTransactions(for:)`, `NutritionCalculator()` instance methods,
/// `ServingSizeCalculator.convertFromGrams(_:toUnit:)`, a `FoodData()`
/// initializer exposing `.commonFoods`, and a `FoodCategory` enum), so the
/// test target could not compile. It is rewritten against the real
/// `CDFood` / `CDMeal` / `CDMealItem` model and the real `DietRepository`,
/// `NutritionCalculator`, `ServingSizeCalculator`, `FoodData` surfaces.
///
/// `CalorieBankManager` is intentionally not exercised here: its `init` is
/// private (only `.shared` exists) and the shared instance is bound to the
/// on-disk store and a repeating `Timer`, which would make these tests
/// non-hermetic.
class DietTests: XCTestCase {
    var controller: PersistenceController!
    var context: NSManagedObjectContext!
    var repository: DietRepository!

    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        repository = DietRepository(context: context)
    }

    override func tearDown() {
        controller = nil
        context = nil
        repository = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a custom food through the repository and links it to `meal`.
    @discardableResult
    private func addFood(
        _ food: CDFood,
        to meal: CDMeal,
        grams: Double
    ) -> CDMealItem? {
        repository.addFoodToMeal(meal, food: food, quantityGrams: grams)
        return (meal.items as? Set<CDMealItem>)?.first { $0.food === food }
    }

    private func items(of meal: CDMeal) -> [CDMealItem] {
        guard let set = meal.items as? Set<CDMealItem> else { return [] }
        return Array(set)
    }

    private func fetchFoods(matching predicate: NSPredicate) -> [CDFood] {
        let request: NSFetchRequest<CDFood> = CDFood.fetchRequest()
        request.predicate = predicate
        return (try? context.fetch(request)) ?? []
    }

    // MARK: - Food Creation Tests

    func testCreateFoodStoresPer100gValues() {
        // `createFood` only takes the per-100 g values; everything else is left
        // at its model default.
        let food = repository.createFood(
            name: "Zzz Test Food",
            caloriesPer100g: 165,
            proteinPer100g: 31.0,
            carbsPer100g: 12.0,
            fatPer100g: 3.6
        )

        XCTAssertNotNil(food.id)
        XCTAssertEqual(food.name, "Zzz Test Food")
        XCTAssertEqual(food.caloriesPer100g, 165)
        XCTAssertEqual(food.proteinPer100g, 31.0, accuracy: 0.0001)
        XCTAssertEqual(food.carbsPer100g, 12.0, accuracy: 0.0001)
        XCTAssertEqual(food.fatPer100g, 3.6, accuracy: 0.0001)
        // Foods created through the repository are flagged as custom.
        XCTAssertTrue(food.isCustom)
    }

    func testCreateFoodIsPublishedInFoodsList() {
        let food = repository.createFood(
            name: "Zzz Published Food",
            caloriesPer100g: 100,
            proteinPer100g: 1,
            carbsPer100g: 1,
            fatPer100g: 1
        )

        // `createFood` calls `fetchFoods()`, so the new food is already in the
        // published list. Phase 2 removed the template seeding from
        // `DietRepository.init` (NUTRITION_MIGRATION_PLAN.md §3.3), so the list
        // holds exactly what this test created and no longer a seeded baseline.
        XCTAssertTrue(repository.foods.contains { $0.objectID == food.objectID })
        XCTAssertEqual(repository.foods.count, 1)

        // `fetchFoods` still sorts by name ascending.
        repository.createFood(
            name: "Aaa Sorted First",
            caloriesPer100g: 100,
            proteinPer100g: 1,
            carbsPer100g: 1,
            fatPer100g: 1
        )
        XCTAssertEqual(repository.foods.first?.name, "Aaa Sorted First")
    }

    // MARK: - Seeding / Food Database Tests

    func testTemplateFoodsAreSeededIntoTheOfficialCatalog() {
        // Phase 2 moved template seeding off `DietRepository.init` — which wrote
        // the legacy `CDFood` entity — and onto `NutritionCatalogSeed`, which
        // writes the official `CDEcksteinFood`. See
        // NUTRITION_MIGRATION_PLAN.md §3.3.
        XCTAssertEqual(repository.foods.count, 0)

        XCTAssertEqual(try? NutritionCatalogSeed.seedIfNeeded(context: context), FoodData.foods.count)
        XCTAssertEqual(try? NutritionCatalogSeed.seedIfNeeded(context: context), 0) // idempotent

        let request: NSFetchRequest<CDEcksteinFood> = CDEcksteinFood.fetchRequest()
        let seeded = try? context.fetch(request)
        XCTAssertEqual(seeded?.count, 34)
        XCTAssertTrue(seeded?.allSatisfy { $0.source == NutritionCatalogSeed.source } ?? false)
    }

    func testSeedingIsIdempotent() {
        // Phase 2 removed the call from `DietRepository.init`. The legacy
        // `FoodData.seedFoodsIfNeeded` still exists and still works, which is
        // what keeps this test valid and old stores readable.
        XCTAssertEqual(repository.foods.count, 0)

        FoodData.seedFoodsIfNeeded(context: context)
        repository.fetchFoods()
        XCTAssertEqual(repository.foods.count, 34)

        // Seeding a second time must not duplicate anything.
        FoodData.seedFoodsIfNeeded(context: context)
        repository.fetchFoods()
        XCTAssertEqual(repository.foods.count, 34)
    }

    func testFoodTemplatesHaveExpectedValues() {
        let foods = FoodData.foods
        XCTAssertFalse(foods.isEmpty)

        // Values below are read from `FoodData.foods` in the app sources.
        let apple = foods.first { $0.name == "Apple" }
        XCTAssertEqual(apple?.caloriesPer100g, 52)
        XCTAssertEqual(apple?.carbsPer100g, 14.0)
        XCTAssertEqual(apple?.servingSize, 182.0)
        XCTAssertEqual(apple?.servingUnit, "g (1 medium)")

        let banana = foods.first { $0.name == "Banana" }
        XCTAssertEqual(banana?.caloriesPer100g, 89)
        XCTAssertEqual(banana?.fiberPer100g, 2.6)
    }

    func testFoodTemplatesCoverExpectedCategories() {
        // `FoodCategory` does not exist; the template `category` strings are the
        // real source of truth.
        let categories = Set(FoodData.foods.map(\.category))
        XCTAssertEqual(
            categories,
            ["Carbs", "Dairy", "Fats", "Fruit", "Nuts", "Protein", "Snack", "Supplement", "Vegetable"]
        )
    }

    func testFoodCategoriesArePresentOnSeededFoods() {
        // Phase 2 removed the seeding from `DietRepository.init`, so the legacy
        // catalog is seeded explicitly here. The legacy path still has to work:
        // shipped stores hold rows it wrote, and phase 2 does not delete it.
        FoodData.seedFoodsIfNeeded(context: context)
        repository.fetchFoods()

        let seededCategories = Set(repository.foods.compactMap(\.category))
        XCTAssertTrue(seededCategories.contains("Protein"))
        XCTAssertTrue(seededCategories.contains("Fruit"))
        // Seeded templates carry their category through to the managed object.
        let chicken = repository.foods.first { $0.name == "Chicken Breast (Cooked)" }
        XCTAssertEqual(chicken?.category, "Protein")
        XCTAssertEqual(chicken?.caloriesPer100g, 165)
    }

    // MARK: - Meal Management Tests

    func testCreateMealSetsTypeAndDate() {
        let date = Date()
        let meal = repository.createMeal(mealType: MealType.lunch.rawValue, date: date)

        XCTAssertNotNil(meal.id)
        XCTAssertEqual(meal.mealType, "lunch")
        XCTAssertEqual(meal.mealType, MealType.lunch.rawValue)
        XCTAssertEqual(meal.date, date)
        // A freshly created meal has no items.
        XCTAssertEqual(items(of: meal).count, 0)
    }

    func testMealTypeEnumMatchesStoredStrings() {
        // The four slots a user can pick keep the strings this store has always
        // held, so no stored `mealType` is invalidated.
        //
        // `MealType` also carries `.unspecified` — the bucket for entries
        // written before a slot was recorded — which is deliberately not a
        // choice and is never persisted (its `storedValue` is `nil`). See
        // NUTRITION_MIGRATION_PLAN.md §6.
        XCTAssertEqual(
            MealType.selectableCases.map(\.rawValue),
            ["breakfast", "lunch", "dinner", "snack"]
        )
        XCTAssertEqual(MealType.unspecified.rawValue, "unspecified")
        XCTAssertNil(MealType.unspecified.storedValue)
    }

    func testAddFoodToMealLinksItemWithQuantity() {
        let meal = repository.createMeal(mealType: MealType.breakfast.rawValue, date: Date())
        let food = repository.createFood(
            name: "Zzz Oatmeal",
            caloriesPer100g: 150,
            proteinPer100g: 5.0,
            carbsPer100g: 27.0,
            fatPer100g: 3.0
        )

        let item = addFood(food, to: meal, grams: 150)

        // `addFoodToMeal` returns Void; the link is observable on the model.
        let mealItems = items(of: meal)
        XCTAssertEqual(mealItems.count, 1)
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.quantityGrams ?? 0, 150, accuracy: 0.0001)
        XCTAssertTrue(item?.food === food)
        XCTAssertTrue(item?.meal === meal)
        XCTAssertTrue(item?.id != nil)
    }

    func testMealNutritionSumsAcrossFoods() {
        let meal = repository.createMeal(mealType: MealType.dinner.rawValue, date: Date())

        // Values taken verbatim from `FoodData.foods` (per 100 g).
        let recipes: [(String, Int32, Double, Double, Double)] = [
            ("Chicken Breast (Cooked)", 165, 31.0, 0.0, 3.6),
            ("Brown Rice (Cooked)", 111, 2.6, 23.0, 0.9),
            ("Broccoli (Cooked)", 35, 2.4, 7.2, 0.4)
        ]

        for (name, calories, protein, carbs, fat) in recipes {
            let food = repository.createFood(
                name: "Zzz \(name)",
                caloriesPer100g: calories,
                proteinPer100g: protein,
                carbsPer100g: carbs,
                fatPer100g: fat
            )
            addFood(food, to: meal, grams: 100)
        }

        let nutrition = NutritionCalculator.calculateNutritionForMeals([meal])

        XCTAssertEqual(items(of: meal).count, 3)
        // Each food is a 100 g serving, so the multiplier is 1.0.
        XCTAssertEqual(nutrition.calories, 165 + 111 + 35)
        XCTAssertEqual(nutrition.protein, 31.0 + 2.6 + 2.4, accuracy: 0.0001)
        XCTAssertEqual(nutrition.carbs, 0.0 + 23.0 + 7.2, accuracy: 0.0001)
        XCTAssertEqual(nutrition.fat, 3.6 + 0.9 + 0.4, accuracy: 0.0001)
    }

    func testNutritionForMealWithoutItemsIsZero() {
        let meal = repository.createMeal(mealType: MealType.snack.rawValue, date: Date())
        let nutrition = NutritionCalculator.calculateNutritionForMeals([meal])

        XCTAssertEqual(nutrition.calories, 0)
        XCTAssertEqual(nutrition.protein, 0, accuracy: 0.0001)
        XCTAssertEqual(nutrition.carbs, 0, accuracy: 0.0001)
        XCTAssertEqual(nutrition.fat, 0, accuracy: 0.0001)
        XCTAssertEqual(nutrition.fiber, 0, accuracy: 0.0001)
    }

    func testCalculateTodayCaloriesSumsTodaysMeals() {
        let meal = repository.createMeal(mealType: MealType.breakfast.rawValue, date: Date())

        let foodA = repository.createFood(
            name: "Zzz A",
            caloriesPer100g: 100,
            proteinPer100g: 10,
            carbsPer100g: 0,
            fatPer100g: 0
        )
        let foodB = repository.createFood(
            name: "Zzz B",
            caloriesPer100g: 200,
            proteinPer100g: 0,
            carbsPer100g: 0,
            fatPer100g: 10
        )

        addFood(foodA, to: meal, grams: 100)
        addFood(foodB, to: meal, grams: 50)

        // `calculateTodayCalories` uses ServingSizeCalculator per item:
        // A -> Int(100 * 100/100) = 100, B -> Int(200 * 50/100) = 100.
        XCTAssertEqual(repository.todayMeals.count, 1)
        XCTAssertEqual(repository.calculateTodayCalories(), 200)
    }

    // MARK: - Fetching Tests

    func testFetchMealsInDateRangeIsInclusive() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let inside = calendar.date(byAdding: .day, value: 2, to: start)!
        let outside = calendar.date(byAdding: .day, value: 5, to: start)!

        _ = repository.createMeal(mealType: MealType.breakfast.rawValue, date: start)
        _ = repository.createMeal(mealType: MealType.lunch.rawValue, date: inside)
        _ = repository.createMeal(mealType: MealType.dinner.rawValue, date: outside)

        // The predicate is `date >= start AND date <= end`, so both bounds count.
        let meals = repository.fetchMeals(from: start, to: inside)
        XCTAssertEqual(meals.count, 2)
        XCTAssertEqual(Set(meals.compactMap(\.mealType)), ["breakfast", "lunch"])
    }

    func testFetchMealsSortsByDateDescending() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: today)!

        _ = repository.createMeal(mealType: MealType.breakfast.rawValue, date: lastWeek)
        _ = repository.createMeal(mealType: MealType.lunch.rawValue, date: today)
        _ = repository.createMeal(mealType: MealType.dinner.rawValue, date: yesterday)

        repository.fetchMeals()

        XCTAssertEqual(repository.meals.count, 3)
        XCTAssertEqual(repository.meals.first?.date, today)
        XCTAssertEqual(repository.meals.last?.date, lastWeek)
    }

    func testFetchTodayMealsExcludesOtherDays() {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        _ = repository.createMeal(mealType: MealType.breakfast.rawValue, date: Date())
        _ = repository.createMeal(mealType: MealType.lunch.rawValue, date: yesterday)

        repository.fetchTodayMeals()

        XCTAssertEqual(repository.todayMeals.count, 1)
        XCTAssertEqual(repository.todayMeals.first?.mealType, "breakfast")
    }

    // MARK: - Deletion Tests

    func testDeleteMealRemovesItFromStore() {
        let meal = repository.createMeal(mealType: MealType.lunch.rawValue, date: Date())
        repository.fetchMeals()
        XCTAssertEqual(repository.meals.count, 1)

        repository.delete(meal)

        let request: NSFetchRequest<CDMeal> = CDMeal.fetchRequest()
        let remaining = (try? context.fetch(request)) ?? []
        XCTAssertTrue(remaining.isEmpty)
    }

    func testDeletingMealCascadesToItems() {
        let meal = repository.createMeal(mealType: MealType.dinner.rawValue, date: Date())
        let food = repository.createFood(
            name: "Zzz Cascade",
            caloriesPer100g: 100,
            proteinPer100g: 1,
            carbsPer100g: 1,
            fatPer100g: 1
        )
        addFood(food, to: meal, grams: 100)
        try? context.save()
        XCTAssertEqual(items(of: meal).count, 1)

        context.delete(meal)
        try? context.save()

        // The model declares meal -> items as Cascade.
        let request: NSFetchRequest<CDMealItem> = CDMealItem.fetchRequest()
        let remainingItems = (try? context.fetch(request)) ?? []
        XCTAssertTrue(remainingItems.isEmpty, "Deleting a meal should cascade to its items")
        // The food itself survives (the item relationship is Nullify).
        XCTAssertTrue(repository.foods.contains { $0.objectID == food.objectID })
    }

    func testDeleteFoodRemovesItFromFoodsList() {
        let food = repository.createFood(
            name: "Zzz To Delete",
            caloriesPer100g: 100,
            proteinPer100g: 1,
            carbsPer100g: 1,
            fatPer100g: 1
        )
        // Phase 2 removed the seeded baseline from `DietRepository.init`, so the
        // list holds only this test's food.
        XCTAssertEqual(repository.foods.count, 1)

        repository.delete(food)

        XCTAssertEqual(repository.foods.count, 0)
        XCTAssertFalse(repository.foods.contains { $0.objectID == food.objectID })
    }

    // MARK: - Barcode / Search Tests

    func testBarcodeIsStoredAndFetchableByPredicate() {
        let food = repository.createFood(
            name: "Zzz Protein Bar",
            caloriesPer100g: 200,
            proteinPer100g: 20.0,
            carbsPer100g: 25.0,
            fatPer100g: 8.0
        )
        food.brand = "Test Brand"
        food.barcode = "1234567890"
        try? context.save()

        XCTAssertEqual(food.brand, "Test Brand")
        XCTAssertEqual(food.barcode, "1234567890")

        // `DietRepository` has no `searchFoods`; a barcode lookup is a predicate
        // fetch on `CDFood`.
        let matches = fetchFoods(matching: NSPredicate(format: "barcode == %@", "1234567890"))
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.name, "Zzz Protein Bar")
        XCTAssertEqual(matches.first?.brand, "Test Brand")
    }

    func testNameSearchPredicateIsCaseInsensitiveAndContains() {
        let names = ["Zzz Banana", "Zzz Banana Bread", "Zzz Apple"]
        for name in names {
            _ = repository.createFood(
                name: name,
                caloriesPer100g: 100,
                proteinPer100g: 1,
                carbsPer100g: 1,
                fatPer100g: 1
            )
        }

        // The `CONTAINS[cd]` predicate mirrors the one `DietViewModel.searchFoods`
        // builds (case- and diacritic-insensitive substring match).
        let all = fetchFoods(matching: NSPredicate(format: "name CONTAINS[cd] %@", "zzz"))
        XCTAssertEqual(all.count, 3)

        let bananas = fetchFoods(matching: NSPredicate(format: "name CONTAINS[cd] %@", "zzz bAnAnA"))
        XCTAssertEqual(bananas.count, 2)
        XCTAssertEqual(Set(bananas.compactMap(\.name)), ["Zzz Banana", "Zzz Banana Bread"])
    }

    // MARK: - Serving Size Calculator Tests

    func testConvertToGramsUsesServingUnitTable() {
        // Factors come from `ServingSizeCalculator.servingUnits`.
        XCTAssertEqual(ServingSizeCalculator.servingUnits["oz"] ?? 0, 28.35, accuracy: 0.0001)

        // 100 oz * 28.35 g/oz = 2835 g
        XCTAssertEqual(ServingSizeCalculator.convertToGrams(amount: 100, unit: "oz"), 2835.0, accuracy: 0.0001)
        // 1 cup = 240 g
        XCTAssertEqual(ServingSizeCalculator.convertToGrams(amount: 1, unit: "cup"), 240.0, accuracy: 0.0001)
        // 2 tbsp * 15 g/tbsp = 30 g
        XCTAssertEqual(ServingSizeCalculator.convertToGrams(amount: 2, unit: "tbsp"), 30.0, accuracy: 0.0001)
        // Grams pass straight through.
        XCTAssertEqual(ServingSizeCalculator.convertToGrams(amount: 250, unit: "g"), 250.0, accuracy: 0.0001)
        XCTAssertEqual(ServingSizeCalculator.convertToGrams(amount: 250, unit: "grams"), 250.0, accuracy: 0.0001)
        // Unknown units are assumed to already be grams.
        XCTAssertEqual(ServingSizeCalculator.convertToGrams(amount: 42, unit: "furlong"), 42.0, accuracy: 0.0001)
        // Lookups are lowercased.
        XCTAssertEqual(ServingSizeCalculator.convertToGrams(amount: 1, unit: "OZ"), 28.35, accuracy: 0.0001)
    }

    func testCalculateNutritionScalesWithServingGrams() {
        let food = repository.createFood(
            name: "Zzz Scaler",
            caloriesPer100g: 165,
            proteinPer100g: 31.0,
            carbsPer100g: 12.0,
            fatPer100g: 3.6
        )
        food.fiberPer100g = 4.0

        // multiplier = 50 / 100 = 0.5
        let half = ServingSizeCalculator.calculateNutrition(for: food, servingGrams: 50)
        // Int(165 * 0.5) == Int(82.5) == 82 — `Int(_:)` truncates toward zero.
        XCTAssertEqual(half.calories, 82)
        XCTAssertEqual(half.protein, 15.5, accuracy: 0.0001)
        XCTAssertEqual(half.carbs, 6.0, accuracy: 0.0001)
        XCTAssertEqual(half.fat, 1.8, accuracy: 0.0001)
        XCTAssertEqual(half.fiber, 2.0, accuracy: 0.0001)

        // multiplier = 200 / 100 = 2.0
        let double = ServingSizeCalculator.calculateNutrition(for: food, servingGrams: 200)
        XCTAssertEqual(double.calories, 330)
        XCTAssertEqual(double.protein, 62.0, accuracy: 0.0001)

        // Portion percentages are derived from the macro grams.
        // totalMacros = 62 + 24 + 7.2 = 93.2
        XCTAssertEqual(double.totalMacros, 93.2, accuracy: 0.0001)
        XCTAssertEqual(double.proteinPercentage, 62.0 / 93.2 * 100, accuracy: 0.0001)
    }

    func testFormatServingRoundsToWholeNumbers() {
        XCTAssertEqual(ServingSizeCalculator.formatServing(100, unit: "g"), "100 g")
        XCTAssertEqual(ServingSizeCalculator.formatServing(1.5, unit: "cup"), "1.5 cup")
    }

    func testSuggestedServingsPerCategory() {
        // Category lookups are lowercased; unknown/nil falls back to 100 g.
        let protein = ServingSizeCalculator.suggestedServings(for: "Protein")
        XCTAssertEqual(protein.count, 3)
        XCTAssertEqual(protein.first?.amount ?? 0, 100.0, accuracy: 0.0001)
        XCTAssertEqual(protein.first?.unit, "g")

        let unknown = ServingSizeCalculator.suggestedServings(for: nil)
        XCTAssertEqual(unknown.count, 1)
        XCTAssertEqual(unknown.first?.amount ?? 0, 100.0, accuracy: 0.0001)
        XCTAssertEqual(unknown.first?.unit, "g")
    }

    // MARK: - Nutrition Calculator Tests

    func testDailyCalorieNeedsUsesMifflinStJeor() {
        // BMR (male) = 10*70 + 6.25*175 - 5*30 + 5 = 1648.75
        // TDEE = BMR * 1.55 (moderatelyActive) = 2555.5625 -> Int() = 2555
        let male = NutritionCalculator.calculateDailyCalorieNeeds(
            weight: 70,
            height: 175,
            age: 30,
            gender: .male,
            activityLevel: .moderatelyActive
        )
        XCTAssertEqual(male, 2555)

        // BMR (female) = 10*70 + 6.25*175 - 5*30 - 161 = 1482.75
        // TDEE = 1482.75 * 1.55 = 2298.2625 -> 2298
        let female = NutritionCalculator.calculateDailyCalorieNeeds(
            weight: 70,
            height: 175,
            age: 30,
            gender: .female,
            activityLevel: .moderatelyActive
        )
        XCTAssertEqual(female, 2298)

        // Sedentary multiplier is 1.2: 1648.75 * 1.2 = 1978.5 -> 1978
        let sedentary = NutritionCalculator.calculateDailyCalorieNeeds(
            weight: 70,
            height: 175,
            age: 30,
            gender: .male,
            activityLevel: .sedentary
        )
        XCTAssertEqual(sedentary, 1978)
        XCTAssertGreaterThan(male, sedentary)
    }

    func testMacroTargetsForMaintainGoal() {
        // maintain = 25% protein / 45% carbs / 30% fat, at 4/4/9 kcal per gram.
        // 2555 * 0.25 / 4 = 159.6875 -> 159
        // 2555 * 0.45 / 4 = 287.4375 -> 287
        // 2555 * 0.30 / 9 = 85.1666  -> 85
        let targets = NutritionCalculator.calculateMacroTargets(dailyCalories: 2555, goal: .maintain)

        XCTAssertEqual(targets.protein, 159)
        XCTAssertEqual(targets.carbs, 287)
        XCTAssertEqual(targets.fat, 85)
        XCTAssertEqual(targets.calories, 2555)
    }

    func testMacroTargetsForLoseFatAndCustomGoals() {
        // loseFat = 35% / 35% / 30% at 2000 kcal:
        // 2000 * 0.35 / 4 = 175 ; 2000 * 0.30 / 9 = 66.666 -> 66
        let cut = NutritionCalculator.calculateMacroTargets(dailyCalories: 2000, goal: .loseFat)
        XCTAssertEqual(cut.protein, 175)
        XCTAssertEqual(cut.carbs, 175)
        XCTAssertEqual(cut.fat, 66)
        XCTAssertEqual(cut.calories, 2000)

        // custom = 40% / 40% / 20% at 2000 kcal:
        // 2000 * 0.40 / 4 = 200 ; 2000 * 0.20 / 9 = 44.444 -> 44
        let custom = NutritionCalculator.calculateMacroTargets(
            dailyCalories: 2000,
            goal: .custom(protein: 0.40, carbs: 0.40, fat: 0.20)
        )
        XCTAssertEqual(custom.protein, 200)
        XCTAssertEqual(custom.carbs, 200)
        XCTAssertEqual(custom.fat, 44)
        XCTAssertEqual(custom.calories, 2000)
    }

    func testNutrientDensityScore() {
        // proteinPerCalorie = 20/200*1000 = 100 -> min(100*50, 50) = 50
        // fiberPerCalorie   =  4/200*1000 =  20 -> min(20*20, 50)  = 50
        let dense = NutritionCalculator.calculateNutrientDensityScore(
            nutrition: NutritionInfo(calories: 200, protein: 20, carbs: 0, fat: 0, fiber: 4)
        )
        XCTAssertEqual(dense, 100, accuracy: 0.0001)

        // The score is guarded against a zero-calorie input.
        let empty = NutritionCalculator.calculateNutrientDensityScore(
            nutrition: NutritionInfo(calories: 0, protein: 20, carbs: 0, fat: 0, fiber: 4)
        )
        XCTAssertEqual(empty, 0, accuracy: 0.0001)
    }

    func testNutritionInfoPercentages() {
        let info = NutritionInfo(calories: 500, protein: 30, carbs: 50, fat: 20, fiber: 5)
        // totalMacros = 30 + 50 + 20 = 100
        XCTAssertEqual(info.totalMacros, 100, accuracy: 0.0001)
        XCTAssertEqual(info.proteinPercentage, 30, accuracy: 0.0001)
        XCTAssertEqual(info.carbsPercentage, 50, accuracy: 0.0001)
        XCTAssertEqual(info.fatPercentage, 20, accuracy: 0.0001)
    }

    func testMealTimingSpreadsMealsAcrossTheDay() {
        let calendar = Calendar.current
        let wake = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let sleep = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: Date())!

        let timings = NutritionCalculator.calculateMealTiming(
            wakeTime: wake,
            sleepTime: sleep,
            mealCount: 3
        )

        // 14 awake hours / (3 + 1) = 3.5 h between meals; labels are assigned by
        // position, so the first is breakfast and the last is dinner.
        XCTAssertEqual(timings.count, 3)
        XCTAssertEqual(timings.map(\.mealType), ["breakfast", "lunch", "dinner"])
        XCTAssertTrue(timings.allSatisfy { $0.recommendedTime > wake })
    }
}
