//
//  NutritionService.swift
//  Eckstein
//
//  The single official Nutrition data path.
//
//  Every write into `CDEcksteinMeal` / `CDEcksteinMealEntry` / `CDEcksteinFood`
//  goes through this type, and every aggregate a Dashboard or the AI Coach reads
//  comes out of it as a value — no `NSManagedObject` escapes, so no caller has a
//  reason to start issuing its own fetch requests against Nutrition entities.
//
//  See NUTRITION_MIGRATION_PLAN.md §3.3, §7, §9, §10 and §13.
//

import Foundation
import CoreData

final class NutritionService {

    static let shared = NutritionService()

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    // MARK: - Reading a day

    /// The log entries for `date`, oldest first.
    ///
    /// Filters with the same half-open bounds the aggregator uses, so the fetch
    /// and the maths cannot disagree about which day an entry belongs to.
    func entries(on date: Date, calendar: Calendar = .current) throws -> [CDEcksteinMealEntry] {
        let bounds = NutritionAggregator.dayBounds(containing: date, calendar: calendar)

        let request: NSFetchRequest<CDEcksteinMealEntry> = CDEcksteinMealEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "meal.date >= %@ AND meal.date < %@",
            bounds.start as NSDate,
            bounds.end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDEcksteinMealEntry.foodName, ascending: true)]

        return try context.fetch(request)
    }

    /// The day's entries reduced to plain values, ready for the aggregator.
    ///
    /// Entries with no `meal` are skipped: the date lives on the meal, so an
    /// orphaned entry cannot be placed on a day. (Nothing in the app creates
    /// one; `meal` is Nullify, so deleting a meal is what would.)
    func nutritionEntries(on date: Date, calendar: Calendar = .current) throws -> [NutritionEntry] {
        try entries(on: date, calendar: calendar).compactMap { entry in
            guard let mealDate = entry.meal?.date else { return nil }
            return NutritionEntry(
                date: mealDate,
                mealType: MealType(storedValue: entry.meal?.mealType),
                foodName: entry.foodName ?? "",
                grams: Double(entry.gramsConsumed),
                nutrition: entry.nutritionSnapshot
            )
        }
    }

    /// One day's nutrition totals, against the user's current goals.
    ///
    /// Everything a dashboard or the AI Coach shows for a day comes from here:
    /// the five totals, the per-slot breakdown, and the targets they are read
    /// against. The day is decided by `Calendar`, never by comparing `Date`s.
    func summary(on date: Date, calendar: Calendar = .current) throws -> DailyNutritionSummary {
        NutritionAggregator.summary(
            for: try nutritionEntries(on: date, calendar: calendar),
            on: date,
            calendar: calendar,
            goals: try goals()
        )
    }

    /// One day's nutrition totals — the brief's name for `summary(on:)`.
    ///
    /// Kept as a second spelling so the "one daily summary" entry point is
    /// greppable by the name the project refers to it by.
    func dailySummary(for date: Date = Date(), calendar: Calendar = .current) throws -> DailyNutritionSummary {
        try summary(on: date, calendar: calendar)
    }

    /// One day's totals per meal slot, in `MealType` order with `.unspecified`
    /// last. Empty slots are omitted.
    func mealTypeSummary(
        for date: Date = Date(),
        calendar: Calendar = .current
    ) throws -> [NutritionMealSummary] {
        NutritionAggregator.meals(
            for: try nutritionEntries(on: date, calendar: calendar),
            on: date,
            calendar: calendar
        )
    }

    /// The most recent days that have any logging, newest first.
    ///
    /// Built by walking back from `through` rather than by fetching history, so
    /// it stays correct without an index on `CDEcksteinMeal.date`.
    func recentDays(
        limit: Int,
        through date: Date = Date(),
        maxLookbackDays: Int = 90,
        calendar: Calendar = .current
    ) throws -> [DailyNutritionSummary] {
        guard limit > 0 else { return [] }

        var results: [DailyNutritionSummary] = []
        var day = date

        for _ in 0..<maxLookbackDays {
            let summary = try summary(on: day, calendar: calendar)
            if !summary.isEmpty {
                results.append(summary)
                if results.count == limit { break }
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return results
    }

    /// One summary per day for `days` consecutive calendar days ending on `date`
    /// (inclusive), oldest first.
    ///
    /// Unlike `recentDays(limit:)`, this returns exactly the requested span and
    /// includes days with no logging as empty summaries — which is what a weekly
    /// average or a seven-bar chart needs.
    func summaries(
        endingOn date: Date,
        days: Int,
        calendar: Calendar = .current
    ) throws -> [DailyNutritionSummary] {
        guard days > 0 else { return [] }

        var summaries: [DailyNutritionSummary] = []
        var day = calendar.startOfDay(for: date)

        for _ in 0..<days {
            summaries.append(try summary(on: day, calendar: calendar))
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return summaries.reversed()
    }

    /// A day's meals, each rolled up. This is the shape the AI Coach reads.
    func recentMeals(
        limit: Int,
        through date: Date = Date(),
        maxLookbackDays: Int = 90,
        calendar: Calendar = .current
    ) throws -> [NutritionMealSummary] {
        guard limit > 0 else { return [] }

        var results: [NutritionMealSummary] = []
        var day = date

        for _ in 0..<maxLookbackDays {
            let meals = NutritionAggregator.meals(
                for: try nutritionEntries(on: day, calendar: calendar),
                on: day,
                calendar: calendar
            )
            results.append(contentsOf: meals.reversed())
            if results.count >= limit { break }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return Array(results.prefix(limit))
    }

    // MARK: - Goals

    /// The user's daily targets.
    ///
    /// A missing preferences row yields `.unset` rather than creating one; goal
    /// editing is not part of this phase.
    func goals() throws -> DailyNutritionGoals {
        guard let preferences = try fetchPreferences() else { return .unset }
        return DailyNutritionGoals(
            calories: Double(preferences.dailyCalorieGoal),
            protein: Double(preferences.dailyProteinGoal),
            carbs: Double(preferences.dailyCarbGoal),
            fat: preferences.dailyFatGoal?.doubleValue,
            fiber: preferences.dailyFiberGoal?.doubleValue
        )
    }

    /// Writes the user's daily targets, creating a preferences row if needed.
    ///
    /// `nil` clears a goal. The three pre-existing goals are `Int32` in the
    /// model, so they are rounded rather than silently truncated.
    func setGoals(_ goals: DailyNutritionGoals) throws {
        let preferences: CDUserPreferences
        if let existing = try fetchPreferences() {
            preferences = existing
        } else {
            preferences = CDUserPreferences(context: context)
            preferences.id = UUID()
            preferences.user = try currentUser()
        }

        if let calories = goals.calories { preferences.dailyCalorieGoal = Int32(calories.rounded()) }
        if let protein = goals.protein { preferences.dailyProteinGoal = Int32(protein.rounded()) }
        if let carbs = goals.carbs { preferences.dailyCarbGoal = Int32(carbs.rounded()) }
        preferences.dailyFatGoal = goals.fat.map { NSNumber(value: $0) }
        preferences.dailyFiberGoal = goals.fiber.map { NSNumber(value: $0) }

        try context.save()
    }

    /// The day's totals read against the day's goals.
    ///
    /// Built from `summary(on:)`, so the numbers are the same ones the aggregates
    /// report — this adds the comparison, not a second sum.
    func goalProgress(
        on date: Date = Date(),
        calendar: Calendar = .current
    ) throws -> NutritionGoalProgress {
        NutritionGoalProgress(summary: try summary(on: date, calendar: calendar))
    }

    // MARK: - Writing

    /// Records `grams` of a food against a meal, and returns the entry.
    ///
    /// This is the only write into the day's log. It finds or creates the meal
    /// for that calendar day and `mealNumber`, and merges into an existing entry
    /// for the same food rather than adding a duplicate row — the behaviour the
    /// live diet UI already had, now in one place.
    ///
    /// The nutrition snapshot is recomputed from the per-100 g values of the
    /// resolved `CDEcksteinFood` (scaled to the **new total** grams, so a merge
    /// stays consistent). When no per-100 g values are known the snapshot is
    /// left `nil`, meaning "unknown" — not zero.
    ///
    /// `mealType` is written only when supplied. The Eckstein two-meal UI has no
    /// slot to offer, so it leaves the entry in the `.unspecified` bucket rather
    /// than having a slot guessed for it.
    @discardableResult
    func logEntry(
        foodName: String,
        category: String?,
        grams: Double,
        mealNumber: Int32 = 1,
        mealType: MealType? = nil,
        date: Date = Date(),
        food: CDEcksteinFood? = nil,
        calendar: Calendar = .current
    ) throws -> CDEcksteinMealEntry {
        let meal = try findOrCreateMeal(
            on: date,
            mealNumber: mealNumber,
            mealType: mealType,
            calendar: calendar
        )

        // Prefer the caller's food; otherwise resolve the diet-rule row by its
        // exact name and category, which is how the Eckstein pickers identify a
        // food. A catalog row (category "") will not match a diet-rule entry.
        //
        // `self.` is required: the `food` parameter shadows the same-named
        // lookup method inside this body.
        // `try` covers the whole `??`: the right-hand side is an autoclosure, so
        // a `try` inside the parentheses does not satisfy the compiler.
        let resolvedFood = try food ?? self.food(named: foodName, category: category)

        let existing = meal.entriesArray.first {
            $0.foodName == foodName && $0.category == category
        }

        let entry: CDEcksteinMealEntry
        if let existing = existing {
            entry = existing
            entry.gramsConsumed = Self.addGrams(entry.gramsConsumed, grams)
        } else {
            entry = CDEcksteinMealEntry(context: context)
            entry.id = UUID()
            entry.foodName = foodName
            entry.category = category
            entry.gramsConsumed = Self.gramsToInt32(grams)
            entry.meal = meal
        }

        entry.food = resolvedFood
        applyNutrition(
            to: entry,
            from: resolvedFood,
            grams: Double(entry.gramsConsumed)
        )
        entry.updatedAt = Date()

        recalculateTotals(for: meal)

        try context.save()
        return entry
    }

    /// Deletes an entry and refreshes its meal's cached totals.
    func delete(_ entry: CDEcksteinMealEntry) throws {
        let meal = entry.meal
        context.delete(entry)
        if let meal = meal {
            recalculateTotals(for: meal)
        }
        try context.save()
    }

    // MARK: - Editing an entry

    /// Replaces the grams on an entry and recomputes its snapshot.
    ///
    /// The recompute is the point: the snapshot holds amounts scaled from the
    /// food's per-100 g values, so a corrected weight with the old snapshot left
    /// in place would report the previous meal.
    @discardableResult
    func updateGrams(_ grams: Double, for entry: CDEcksteinMealEntry) throws -> CDEcksteinMealEntry {
        entry.gramsConsumed = Self.gramsToInt32(grams)
        applyNutrition(to: entry, from: entry.food, grams: Double(entry.gramsConsumed))
        entry.updatedAt = Date()
        if let meal = entry.meal { recalculateTotals(for: meal) }
        try context.save()
        return entry
    }

    /// Points an entry at a different food, recomputing its snapshot.
    ///
    /// `food` is the catalog row when the caller has one. When it does not, the
    /// name and category are still recorded and the lookup — or, failing that,
    /// the `DietRuleNutrition` fixture — supplies the values.
    @discardableResult
    func updateEntry(
        _ entry: CDEcksteinMealEntry,
        foodName: String,
        category: String?,
        grams: Double,
        food: CDEcksteinFood? = nil
    ) throws -> CDEcksteinMealEntry {
        entry.foodName = foodName
        entry.category = category
        entry.gramsConsumed = Self.gramsToInt32(grams)

        // `self.` disambiguates the `food` parameter from the same-named lookup,
        // and the `try` has to cover the whole `??` — its right side is an
        // autoclosure, so a `try` inside the parentheses would not compile.
        entry.food = try food ?? self.food(named: foodName, category: category)

        applyNutrition(to: entry, from: entry.food, grams: Double(entry.gramsConsumed))
        entry.updatedAt = Date()
        if let meal = entry.meal { recalculateTotals(for: meal) }
        try context.save()
        return entry
    }

    /// Files an entry's meal under a different slot.
    ///
    /// Deliberately does **not** recompute the entry's snapshot. Which slot a
    /// meal is filed under says nothing about what was eaten, so a recompute here
    /// could only ever produce a value change caused by a bug — and the brief
    /// requires the opposite, that a metadata edit leave the recorded amounts
    /// alone.
    ///
    /// A meal entry has no notes column in this schema — `MealDetailView`'s notes
    /// box is local view state, by its own comment — so the slot is the whole of
    /// the display metadata this phase can record.
    func updateMealType(_ mealType: MealType?, for entry: CDEcksteinMealEntry) throws {
        guard let meal = entry.meal else { return }
        meal.mealType = mealType?.storedValue
        meal.updatedAt = Date()
        try context.save()
    }

    /// Copies an entry into a new row.
    ///
    /// The copy is a new identity throughout: a fresh `UUID`, an `objectID` Core
    /// Data gives the inserted row, and a fresh `updatedAt`. Reusing any of them
    /// would make the copy indistinguishable from its source to the sync layer
    /// and to the HealthKit dedupe key, which is exactly the bug worth avoiding.
    /// (The model has no `createdAt` on an entry, so there is no fourth field to
    /// set.)
    ///
    /// The snapshot is recomputed from the copy's own grams rather than copied
    /// across, so a copy taken after a food's values were corrected carries the
    /// corrected figure — while the original keeps the amounts it was logged
    /// with, which is what the brief requires of history.
    @discardableResult
    func duplicate(
        _ entry: CDEcksteinMealEntry,
        grams: Double? = nil,
        date: Date? = nil,
        mealNumber: Int32? = nil,
        mealType: MealType? = nil,
        calendar: Calendar = .current
    ) throws -> CDEcksteinMealEntry {
        let meal = try findOrCreateMeal(
            on: date ?? entry.meal?.date ?? Date(),
            mealNumber: mealNumber ?? entry.meal?.mealNumber ?? 1,
            mealType: mealType,
            calendar: calendar
        )

        let copy = CDEcksteinMealEntry(context: context)
        copy.id = UUID()
        copy.foodName = entry.foodName
        copy.category = entry.category
        copy.gramsConsumed = grams.map(Self.gramsToInt32) ?? entry.gramsConsumed
        copy.meal = meal
        copy.food = entry.food
        copy.updatedAt = Date()
        applyNutrition(to: copy, from: copy.food, grams: Double(copy.gramsConsumed))

        recalculateTotals(for: meal)
        try context.save()
        return copy
    }

    /// Logs the same food again — the "add again" action on a history row.
    ///
    /// This is the ordinary log path, not a copy: it merges into an entry that
    /// already exists for the same food on the target day, exactly as tapping the
    /// food in the picker would. `logEntry` remains the one implementation of
    /// that rule.
    @discardableResult
    func logAgain(
        _ entry: CDEcksteinMealEntry,
        grams: Double? = nil,
        on date: Date? = nil,
        calendar: Calendar = .current
    ) throws -> CDEcksteinMealEntry {
        try logEntry(
            foodName: entry.foodName ?? "",
            category: entry.category,
            grams: grams ?? Double(entry.gramsConsumed),
            mealNumber: entry.meal?.mealNumber ?? 1,
            mealType: MealType(storedValue: entry.meal?.mealType),
            date: date ?? Date(),
            food: entry.food,
            calendar: calendar
        )
    }

    /// Recomputes a meal's denormalised totals from its entries.
    ///
    /// The totals are a cache for cheap display and for the matching remote
    /// `eckstein_meals` columns. They are never the source of truth —
    /// `NutritionAggregator` recomputes from the entries.
    func recalculateTotals(for meal: CDEcksteinMeal) {
        var totals = NutritionSnapshot.zero
        for entry in meal.entriesArray {
            totals += entry.nutritionSnapshot
        }

        meal.totalCalories = NSNumber(value: totals.calories)
        meal.totalProtein = NSNumber(value: totals.protein)
        meal.totalCarbs = NSNumber(value: totals.carbs)
        meal.totalFat = NSNumber(value: totals.fat)
        meal.totalFiber = NSNumber(value: totals.fiber)
        meal.updatedAt = Date()
    }

    /// Looks up the meal for a calendar day and meal number, creating it if
    /// needed. Fills in `mealType` when the meal has none and a slot is supplied,
    /// but never overwrites a slot that is already recorded.
    func findOrCreateMeal(
        on date: Date,
        mealNumber: Int32,
        mealType: MealType? = nil,
        calendar: Calendar = .current
    ) throws -> CDEcksteinMeal {
        let bounds = NutritionAggregator.dayBounds(containing: date, calendar: calendar)

        let request: NSFetchRequest<CDEcksteinMeal> = CDEcksteinMeal.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND mealNumber == %d",
            bounds.start as NSDate,
            bounds.end as NSDate,
            mealNumber
        )
        request.fetchLimit = 1

        let meal: CDEcksteinMeal
        if let existing = try context.fetch(request).first {
            meal = existing
        } else {
            meal = CDEcksteinMeal(context: context)
            meal.id = UUID()
            meal.date = date
            meal.mealNumber = mealNumber
            meal.isCarbLoad = false
            meal.user = try currentUser()
            meal.updatedAt = Date()
        }

        if meal.mealType == nil, let stored = mealType?.storedValue {
            meal.mealType = stored
        }

        return meal
    }

    // MARK: - Food catalog

    /// Catalog foods whose name contains `query`, favourites and recently used
    /// first. An empty query returns the most recent foods.
    func foods(matching query: String) throws -> [CDEcksteinFood] {
        let request: NSFetchRequest<CDEcksteinFood> = CDEcksteinFood.fetchRequest()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", trimmed)
        }
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDEcksteinFood.isFavorite, ascending: false),
            NSSortDescriptor(keyPath: \CDEcksteinFood.lastUsed, ascending: false),
            NSSortDescriptor(keyPath: \CDEcksteinFood.name, ascending: true)
        ]
        request.fetchLimit = 100
        return try context.fetch(request)
    }

    /// The diet-rule row for a food, matched on exact name **and** category.
    ///
    /// Both are required: the Eckstein pickers key foods by name within a
    /// category, and catalog rows carry an empty category so they can never be
    /// mistaken for a diet rule.
    func food(named name: String, category: String?) throws -> CDEcksteinFood? {
        let request: NSFetchRequest<CDEcksteinFood> = CDEcksteinFood.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND category == %@", name, category ?? "")
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// Looks up a catalog food by barcode. This is the seam the scanner uses, so
    /// the scanner itself never touches Core Data.
    func food(matchingBarcode barcode: String) throws -> CDEcksteinFood? {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let request: NSFetchRequest<CDEcksteinFood> = CDEcksteinFood.fetchRequest()
        request.predicate = NSPredicate(format: "barcode == %@", trimmed)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// Recently logged foods, most recent first.
    func recentFoods(limit: Int = 20) throws -> [CDEcksteinFood] {
        guard limit > 0 else { return [] }
        let request: NSFetchRequest<CDEcksteinFood> = CDEcksteinFood.fetchRequest()
        request.predicate = NSPredicate(format: "lastUsed != nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDEcksteinFood.lastUsed, ascending: false)]
        request.fetchLimit = limit
        return try context.fetch(request)
    }

    /// Favourited foods, alphabetically.
    func favoriteFoods() throws -> [CDEcksteinFood] {
        let request: NSFetchRequest<CDEcksteinFood> = CDEcksteinFood.fetchRequest()
        request.predicate = NSPredicate(format: "isFavorite == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDEcksteinFood.name, ascending: true)]
        return try context.fetch(request)
    }

    func setFavorite(_ food: CDEcksteinFood, isFavorite: Bool) throws {
        food.isFavorite = isFavorite
        food.updatedAt = Date()
        try context.save()
    }

    /// Stamps a food as just used. Called by the write path so "recent foods" is
    /// a query rather than a second table.
    func markUsed(_ food: CDEcksteinFood) throws {
        food.lastUsed = Date()
        food.updatedAt = Date()
        try context.save()
    }

    /// The nutrition in `grams` of a catalog food, or `nil` when nothing is known.
    func nutrition(for food: CDEcksteinFood, grams: Double) -> NutritionSnapshot? {
        NutritionSnapshot.per100g(
            calories: food.caloriesPer100g?.doubleValue,
            protein: food.proteinPer100g?.doubleValue,
            carbs: food.carbsPer100g?.doubleValue,
            fat: food.fatPer100g?.doubleValue,
            fiber: food.fiberPer100g?.doubleValue,
            grams: grams
        )
    }

    // MARK: - Catalog writes

    /// Inserts or updates a catalog food from a model-independent template.
    ///
    /// Matched on barcode when the template has one, otherwise on name and food
    /// group, so scanning the same product twice updates one row instead of
    /// creating two. This is the adapter that lets the existing Open Food Facts
    /// scanner serve the official entity without a second scanner.
    @discardableResult
    func upsertFood(from template: FoodTemplate, source: NutritionSource) throws -> CDEcksteinFood {
        let food = try existingFood(for: template) ?? {
            let created = CDEcksteinFood(context: context)
            created.id = UUID()
            created.createdAt = Date()
            // Catalog rows are not Eckstein diet rules: an empty `category` keeps
            // them out of the diet pickers, which match on `DietCategory` values.
            created.category = ""
            created.dailyGrams = 0
            created.isCustom = false
            return created
        }()

        food.name = template.name
        food.foodCategory = template.category
        food.barcode = template.barcode
        food.brand = template.brand
        food.caloriesPer100g = NSNumber(value: Double(template.caloriesPer100g))
        // `map` rather than `?? 0`: a product that does not declare a macro
        // leaves the column NULL, so "unknown" stays distinguishable from a
        // declared zero.
        food.proteinPer100g = template.proteinPer100g.map { NSNumber(value: $0) }
        food.carbsPer100g = template.carbsPer100g.map { NSNumber(value: $0) }
        food.fatPer100g = template.fatPer100g.map { NSNumber(value: $0) }
        food.fiberPer100g = template.fiberPer100g.map { NSNumber(value: $0) }
        food.servingSize = template.servingSize.map { NSNumber(value: $0) }
        food.servingUnit = template.servingUnit
        food.isVerified = true
        food.updatedAt = Date()
        food.source = source.storedValue

        try context.save()
        return food
    }

    // MARK: - Private

    /// Grams as stored: `CDEcksteinMealEntry.gramsConsumed` is `Int32` (widening
    /// it would be a destructive change to a populated column), so the value is
    /// clamped rather than allowed to trap on a non-finite or absurd input.
    private static func gramsToInt32(_ grams: Double) -> Int32 {
        guard grams.isFinite, grams > 0 else { return 0 }
        return Int32(min(grams.rounded(), Double(Int32.max)))
    }

    private static func addGrams(_ current: Int32, _ additional: Double) -> Int32 {
        let (sum, overflow) = current.addingReportingOverflow(gramsToInt32(additional))
        return overflow ? Int32.max : max(0, sum)
    }

    /// Applies a per-100 g food's values to an entry, scaled to `grams`.
    ///
    /// When nothing is known, the snapshot is cleared to `nil` rather than
    /// written as zeros, so "unknown" stays distinguishable from "zero".
    ///
    /// The resolved catalog row wins. It is not the only source though: the
    /// Eckstein diet rules are logged by name and category, and a row for one
    /// exists only once the Diet screen has seeded it — while the ten carb-load
    /// dishes have no row at all. Falling back to the shipped
    /// `DietRuleNutrition` fixture is what makes a diet-rule meal contribute
    /// calories instead of silently reading zero.
    private func applyNutrition(
        to entry: CDEcksteinMealEntry,
        from food: CDEcksteinFood?,
        grams: Double
    ) {
        // `??` here binds tighter than the `let`, so the fallback is evaluated
        // only when the row is missing or carries no values.
        let snapshot = food.flatMap { nutrition(for: $0, grams: grams) }
            ?? DietRuleNutrition.snapshot(
                foodName: entry.foodName ?? "",
                category: entry.category,
                grams: grams
            )

        guard let snapshot = snapshot else {
            entry.calories = nil
            entry.protein = nil
            entry.carbs = nil
            entry.fat = nil
            entry.fiber = nil
            return
        }

        entry.calories = NSNumber(value: snapshot.calories)
        entry.protein = NSNumber(value: snapshot.protein)
        entry.carbs = NSNumber(value: snapshot.carbs)
        entry.fat = NSNumber(value: snapshot.fat)
        entry.fiber = NSNumber(value: snapshot.fiber)
    }

    private func existingFood(for template: FoodTemplate) throws -> CDEcksteinFood? {
        if let barcode = template.barcode, !barcode.isEmpty {
            let request: NSFetchRequest<CDEcksteinFood> = CDEcksteinFood.fetchRequest()
            request.predicate = NSPredicate(format: "barcode == %@", barcode)
            request.fetchLimit = 1
            if let match = try context.fetch(request).first { return match }
        }

        let request: NSFetchRequest<CDEcksteinFood> = CDEcksteinFood.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND foodCategory == %@", template.name, template.category)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchPreferences() throws -> CDUserPreferences? {
        let request: NSFetchRequest<CDUserPreferences> = CDUserPreferences.fetchRequest()
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// The single `CDUser` row, created on demand.
    ///
    /// Mirrors `EcksteinDietViewModel.getCurrentUser()` — the meal's `user` is
    /// required for the Supabase mapping, which sends `user_id`.
    private func currentUser() throws -> CDUser {
        let request: NSFetchRequest<CDUser> = CDUser.fetchRequest()
        request.fetchLimit = 1
        if let user = try context.fetch(request).first { return user }

        let user = CDUser(context: context)
        user.id = UUID()
        user.email = "user@example.com"
        user.createdAt = Date()
        user.updatedAt = Date()
        user.syncStatus = "pending"
        return user
    }
}
