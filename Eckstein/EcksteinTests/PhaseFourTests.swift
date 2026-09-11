//
//  PhaseFourTests.swift
//  EcksteinTests
//
//  Coverage for the phase-4 business layer: the numbers the Dashboard, the Diet
//  screen, the Progress charts and the Profile goals screen read.
//
//  What is tested here is the *rules*, not the SwiftUI views that render them.
//  A view body is not a place a rule can be asserted against — it can only be
//  photographed — so every value these tests pin down was deliberately put in a
//  plain type first: `WeightMetrics`, `NutrientFormat`, `FoodDraft`,
//  `NutritionGoalDraft`, `BodyHeight`, `FitnessGoal`, `NutritionService`.
//
//  The Core Data tests use `PersistenceController(inMemory: true)`, the same
//  fixture the existing suites use, so nothing here touches the real store.
//

import XCTest
import CoreData
@testable import Eckstein

final class PhaseFourTests: XCTestCase {

    var controller: PersistenceController!
    var context: NSManagedObjectContext!
    var repository: WeightRepository!
    var nutrition: NutritionService!

    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        repository = WeightRepository(context: context)
        nutrition = NutritionService(context: context)

        // Every one of these is read from UserDefaults by production code, so a
        // value left behind by another suite would decide the outcome of a test
        // in this one.
        UserDefaults.standard.removeObject(forKey: BodyHeight.storageKey)
        UserDefaults.standard.removeObject(forKey: FitnessGoal.storageKey)
        UserDefaults.standard.removeObject(forKey: "weightUnit")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: BodyHeight.storageKey)
        UserDefaults.standard.removeObject(forKey: FitnessGoal.storageKey)
        UserDefaults.standard.removeObject(forKey: "weightUnit")

        nutrition = nil
        repository = nil
        context = nil
        controller = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private var calendar: Calendar { Calendar.current }

    /// A day, as an offset back from today.
    private func day(_ daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
    }

    /// An instant on a day, so two readings can be ordered within the same day.
    private func time(_ daysAgo: Int, hour: Int) -> Date {
        let start = calendar.startOfDay(for: day(daysAgo))
        return calendar.date(byAdding: .hour, value: hour, to: start) ?? start
    }

    /// A catalog food with exactly the per-100 g values a test wants.
    @discardableResult
    private func makeFood(
        _ name: String,
        calories: Int = 100,
        protein: Double? = 10,
        carbs: Double? = 20,
        fat: Double? = 5,
        fiber: Double? = 2
    ) throws -> CDEcksteinFood {
        try nutrition.upsertFood(
            from: FoodTemplate(
                name: name,
                category: "Test",
                barcode: nil,
                caloriesPer100g: calories,
                proteinPer100g: protein,
                carbsPer100g: carbs,
                fatPer100g: fat,
                fiberPer100g: fiber,
                brand: nil,
                servingSize: nil,
                servingUnit: nil
            ),
            source: .manual
        )
    }

    /// Logs `grams` of a catalog food.
    @discardableResult
    private func log(
        _ food: CDEcksteinFood,
        grams: Double,
        slot: MealType = .breakfast,
        on date: Date
    ) throws -> CDEcksteinMealEntry {
        try nutrition.logEntry(
            foodName: food.name ?? "",
            category: food.category,
            grams: grams,
            mealNumber: slot.slotMealNumber,
            mealType: slot.storedValue == nil ? nil : slot,
            date: date,
            food: food,
            calendar: calendar
        )
    }
}

// MARK: - Dashboard: totals read against goals (§4)

extension PhaseFourTests {

    /// Every figure the Dashboard's nutrition card shows, from one logged food.
    func testGoalProgressReportsConsumedAndTarget() throws {
        try nutrition.setGoals(DailyNutritionGoals(calories: 2000, protein: 150))
        let food = try makeFood("Test Oats", calories: 100, protein: 10, carbs: 20, fat: 5, fiber: 2)
        try log(food, grams: 200, on: Date())

        let progress = try nutrition.goalProgress(on: Date(), calendar: calendar)

        XCTAssertEqual(progress.calories.current, 200, accuracy: 0.001)
        XCTAssertEqual(progress.calories.target, 2000)
        XCTAssertEqual(progress.calories.remaining, 1800)
        XCTAssertEqual(progress.calories.displayProgress, 0.1, accuracy: 0.0001)
        XCTAssertFalse(progress.calories.isOverTarget)

        XCTAssertEqual(progress.protein.current, 20, accuracy: 0.001)
        XCTAssertEqual(progress.protein.target, 150)
    }

    /// The brief's rule: the ring clamps at full for drawing, the business figure
    /// does not. Both are asserted, because clamping one by fixing the other is
    /// exactly the mistake this split exists to prevent.
    func testOverTargetClampsTheDrawingButNotTheRemaining() throws {
        try nutrition.setGoals(DailyNutritionGoals(calories: 100))
        let food = try makeFood("Test Dense", calories: 100)
        try log(food, grams: 200, on: Date())

        let calories = try nutrition.goalProgress(on: Date(), calendar: calendar).calories

        XCTAssertEqual(calories.current, 200, accuracy: 0.001)
        XCTAssertEqual(calories.remaining, -100)
        XCTAssertEqual(calories.displayProgress, 1.0)
        XCTAssertEqual(calories.progress, 2.0)
        XCTAssertTrue(calories.isOverTarget)
        XCTAssertTrue(calories.isTargetMet)
    }

    /// With no goal stored, every derived figure is `nil` rather than zero — a
    /// target of zero would put the user over budget the moment they ate.
    func testNoGoalLeavesTargetAndDerivedFiguresNil() throws {
        let food = try makeFood("Test Rice", calories: 130)
        try log(food, grams: 150, on: Date())

        let progress = try nutrition.goalProgress(on: Date(), calendar: calendar)

        XCTAssertEqual(progress.calories.current, 195, accuracy: 0.001)
        XCTAssertNil(progress.calories.target)
        XCTAssertNil(progress.calories.remaining)
        XCTAssertNil(progress.calories.progress)
        XCTAssertEqual(progress.calories.displayProgress, 0)
        XCTAssertFalse(progress.calories.isOverTarget)
        XCTAssertFalse(progress.calories.isTargetMet)

        for component in progress.allComponents {
            XCTAssertNil(component.progress.target, "\(component.name) should have no target")
        }
    }

    /// A day nobody logged is all zeros, not a crash and not a division by zero.
    func testEmptyDayAgainstATargetIsZeroConsumed() throws {
        try nutrition.setGoals(DailyNutritionGoals(calories: 2000))

        let progress = try nutrition.goalProgress(on: day(3), calendar: calendar)

        XCTAssertEqual(progress.calories.current, 0)
        XCTAssertEqual(progress.calories.remaining, 2000)
        XCTAssertEqual(progress.calories.displayProgress, 0)
        XCTAssertFalse(progress.calories.isOverTarget)
    }

    /// The macros the Dashboard lists come from the same summary the Diet screen
    /// totals, so the two screens cannot show different numbers for one day.
    func testGoalProgressMatchesTheDailySummaryItIsBuiltFrom() throws {
        try nutrition.setGoals(DailyNutritionGoals(calories: 2000, protein: 150, carbs: 250, fat: 70, fiber: 30))
        let food = try makeFood("Test Mix", calories: 200, protein: 12, carbs: 30, fat: 8, fiber: 4)
        try log(food, grams: 250, on: Date())

        let summary = try nutrition.dailySummary(for: Date(), calendar: calendar)
        let progress = NutritionGoalProgress(summary: summary)

        XCTAssertEqual(progress.calories.current, summary.dailyCalories, accuracy: 0.001)
        XCTAssertEqual(progress.protein.current, summary.dailyProtein, accuracy: 0.001)
        XCTAssertEqual(progress.carbohydrates.current, summary.dailyCarbohydrates, accuracy: 0.001)
        XCTAssertEqual(progress.fat.current, summary.dailyFat, accuracy: 0.001)
        XCTAssertEqual(progress.fiber.current, summary.dailyFiber, accuracy: 0.001)
    }

    /// `displayProgress` reports `0`, not `1`, when there is nothing to divide by.
    func testZeroTargetIsNotTreatedAsFullyConsumed() {
        let progress = NutrientGoalProgress(current: 100, target: 0)
        XCTAssertNil(progress.progress)
        XCTAssertEqual(progress.displayProgress, 0)
        XCTAssertFalse(progress.isOverTarget)
    }
}

// MARK: - Weight: which reading is "current" (§15–§17)

extension PhaseFourTests {

    /// The headline rule. The newest reading by date wins, and it is the same
    /// answer whether it was the first or the last row written.
    func testCurrentWeightIsTheNewestByDateNotByInsertionOrder() throws {
        _ = repository.createWeightEntry(weight: 80.0, date: day(1), source: "manual")
        _ = repository.createWeightEntry(weight: 75.0, date: day(10), source: "manual")
        _ = repository.createWeightEntry(weight: 78.0, date: day(3), source: "manual")
        repository.refresh()

        XCTAssertEqual(WeightMetrics.currentWeight(from: repository.weightEntries), 80.0)
    }

    /// A weigh-in with no date cannot be placed on a time axis, so it is not
    /// allowed to become "current".
    func testCurrentWeightIgnoresAnUndatedReading() throws {
        _ = repository.createWeightEntry(weight: 70.0, date: day(5), source: "manual")
        let undated = repository.createWeightEntry(weight: 99.0, date: day(0), source: "manual")
        undated.date = nil
        try context.save()
        repository.refresh()

        XCTAssertEqual(WeightMetrics.currentWeight(from: repository.weightEntries), 70.0)
    }

    func testCurrentWeightIsNilWithNoEntries() {
        repository.refresh()
        XCTAssertNil(WeightMetrics.currentWeight(from: repository.weightEntries))
    }

    /// The series covers every day in the range, oldest first, and leaves the
    /// days nobody weighed in as `nil` rather than as zero.
    func testDailySeriesHasOnePointPerDayAndGapsStayGaps() {
        let entries: [(date: Date, weightKg: Double, id: UUID)] = [
            (date: day(2), weightKg: 80.0, id: UUID())
        ]

        let points = WeightMetrics.dailySeries(from: entries, endingOn: day(0), range: .week, calendar: calendar)

        XCTAssertEqual(points.count, 7)
        XCTAssertEqual(points.compactMap(\.weightKg).count, 1)
        XCTAssertEqual(points[4].weightKg, 80.0)
        XCTAssertNil(points[0].weightKg)
        XCTAssertNil(points[6].weightKg)
        // Oldest first.
        XCTAssertTrue(points[0].date < points[6].date)
    }

    /// Same-day resolution: the latest reading of the day is the day's number.
    func testSameDayKeepsTheLatestReading() {
        let entries: [(date: Date, weightKg: Double, id: UUID)] = [
            (date: time(0, hour: 7), weightKg: 80.0, id: UUID()),
            (date: time(0, hour: 20), weightKg: 79.0, id: UUID())
        ]

        let byDay = WeightMetrics.latestByDay(entries, calendar: calendar)

        XCTAssertEqual(byDay.count, 1)
        XCTAssertEqual(byDay[calendar.startOfDay(for: day(0))], 79.0)
    }

    /// Two readings at the same instant are indistinguishable by date, so the
    /// tie is broken by id — an arbitrary answer, but always the same one.
    func testSameDayTieIsBrokenDeterministically() {
        let earlier = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let later = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let instant = time(0, hour: 7)

        let forwards: [(date: Date, weightKg: Double, id: UUID)] = [
            (date: instant, weightKg: 80.0, id: earlier),
            (date: instant, weightKg: 79.0, id: later)
        ]
        let backwards = Array(forwards.reversed())

        XCTAssertEqual(WeightMetrics.latestByDay(forwards, calendar: calendar).count, 1)
        XCTAssertEqual(
            WeightMetrics.latestByDay(forwards, calendar: calendar)[calendar.startOfDay(for: instant)],
            WeightMetrics.latestByDay(backwards, calendar: calendar)[calendar.startOfDay(for: instant)]
        )
    }

    /// One point is not a trend: there is nothing to measure a change against.
    func testChangeOverRangeIsNilForZeroOrOnePoints() {
        let noEntries: [(date: Date, weightKg: Double, id: UUID)] = []
        let none = WeightMetrics.dailySeries(
            from: noEntries, endingOn: day(0), range: .week, calendar: calendar
        )
        XCTAssertEqual(none.count, 7)
        XCTAssertNil(WeightMetrics.changeOverRange(none))

        let one: [(date: Date, weightKg: Double, id: UUID)] = [(date: day(0), weightKg: 80.0, id: UUID())]
        let single = WeightMetrics.dailySeries(from: one, endingOn: day(0), range: .week, calendar: calendar)
        XCTAssertNil(WeightMetrics.changeOverRange(single))
    }

    func testChangeOverRangeIsLastMinusFirst() {
        let entries: [(date: Date, weightKg: Double, id: UUID)] = [
            (date: day(5), weightKg: 82.0, id: UUID()),
            (date: day(2), weightKg: 81.0, id: UUID()),
            (date: day(0), weightKg: 79.5, id: UUID())
        ]

        let points = WeightMetrics.dailySeries(from: entries, endingOn: day(0), range: .week, calendar: calendar)

        XCTAssertEqual(WeightMetrics.changeOverRange(points) ?? .nan, -2.5, accuracy: 0.0001)
    }

    /// The range picker's four spans are the ones the brief names.
    func testWeightRangeSpansMatchTheBrief() {
        XCTAssertEqual(WeightRange.week.days, 7)
        XCTAssertEqual(WeightRange.month.days, 30)
        XCTAssertEqual(WeightRange.quarter.days, 90)
        XCTAssertEqual(WeightRange.year.days, 365)
        XCTAssertEqual(WeightRange.allCases.count, 4)
    }

    /// A 30-day series is 30 points, not 30 fetches' worth of anything else.
    func testLongRangeSeriesKeepsItsLength() {
        let entries: [(date: Date, weightKg: Double, id: UUID)] = [
            (date: day(400), weightKg: 90.0, id: UUID())
        ]
        let points = WeightMetrics.dailySeries(from: entries, endingOn: day(0), range: .year, calendar: calendar)
        XCTAssertEqual(points.count, 365)
        XCTAssertTrue(points.allSatisfy { $0.weightKg == nil })
    }
}

// MARK: - BMI (§19)

extension PhaseFourTests {

    func testBMIComputesFromWeightAndHeight() {
        let bmi = WeightMetrics.bmi(weightKg: 70, heightCm: 175)
        XCTAssertEqual(bmi ?? .nan, 22.857, accuracy: 0.001)
        XCTAssertEqual(WeightMetrics.formattedBMI(weightKg: 70, heightCm: 175), "22.9")
    }

    /// A missing height is not zero: 0/0 would be a confident NaN.
    func testBMIIsNilWithoutAHeight() {
        XCTAssertNil(WeightMetrics.bmi(weightKg: 70, heightCm: nil))
        XCTAssertNil(WeightMetrics.formattedBMI(weightKg: 70, heightCm: nil))
    }

    func testBMIIsNilWithoutAWeight() {
        XCTAssertNil(WeightMetrics.bmi(weightKg: nil, heightCm: 175))
    }

    /// A height that is a typo or a unit mix-up is refused rather than squared
    /// into a wrong number. 170 in inches, 1.7 in metres, 0, and a negative.
    func testBMIIsNilForAnImplausibleHeight() {
        for height in [0.0, 1.7, 49.9, 260.1, 1700, -175] {
            XCTAssertNil(
                WeightMetrics.bmi(weightKg: 70, heightCm: height),
                "height \(height) should not produce a BMI"
            )
        }
    }

    func testBMIIsNilForANonPositiveOrNonFiniteWeight() {
        for weight in [0.0, -70, Double.nan, .infinity] {
            XCTAssertNil(
                WeightMetrics.bmi(weightKg: weight, heightCm: 175),
                "weight \(weight) should not produce a BMI"
            )
        }
    }

    /// The editor and the calculation share one range, so a height the editor
    /// accepts is never one the calculation will refuse.
    func testHeightValidityMatchesTheEditorsRange() {
        XCTAssertTrue(WeightMetrics.isValidHeight(50))
        XCTAssertTrue(WeightMetrics.isValidHeight(260))
        XCTAssertTrue(WeightMetrics.isValidHeight(175.5))
        XCTAssertFalse(WeightMetrics.isValidHeight(49.9))
        XCTAssertFalse(WeightMetrics.isValidHeight(260.1))
        XCTAssertFalse(WeightMetrics.isValidHeight(nil))
        XCTAssertFalse(WeightMetrics.isValidHeight(.nan))
        XCTAssertFalse(WeightMetrics.isValidHeight(.infinity))
        XCTAssertEqual(WeightMetrics.plausibleHeightCm.lowerBound, 50)
        XCTAssertEqual(WeightMetrics.plausibleHeightCm.upperBound, 260)
    }

    /// The bands are the conventional adult cut-offs, and every edge is placed
    /// on the upper side so 25.0 is not reported as a healthy weight.
    func testBMICategoryBoundaries() {
        XCTAssertEqual(WeightMetrics.bmiCategory(for: 18.49), .underweight)
        XCTAssertEqual(WeightMetrics.bmiCategory(for: 18.5), .normal)
        XCTAssertEqual(WeightMetrics.bmiCategory(for: 24.99), .normal)
        XCTAssertEqual(WeightMetrics.bmiCategory(for: 25), .overweight)
        XCTAssertEqual(WeightMetrics.bmiCategory(for: 29.99), .overweight)
        XCTAssertEqual(WeightMetrics.bmiCategory(for: 30), .obese)
        XCTAssertEqual(WeightMetrics.bmiCategory(for: 41), .obese)
    }

    func testBMICategoryIsNilWithoutAUsableNumber() {
        XCTAssertNil(WeightMetrics.bmiCategory(for: nil))
        XCTAssertNil(WeightMetrics.bmiCategory(for: 0))
        XCTAssertNil(WeightMetrics.bmiCategory(for: -22))
        XCTAssertNil(WeightMetrics.bmiCategory(for: .nan))
    }

    /// The label behind each band is a localization key, never clinical text.
    func testBMICategoriesHaveDistinctLocalizationKeys() {
        let keys = BMICategory.allCases.map(\.titleKey)
        XCTAssertEqual(Set(keys).count, BMICategory.allCases.count)
        XCTAssertTrue(keys.allSatisfy { $0.hasPrefix("bmi_") })
    }
}

// MARK: - Distance to a target weight (§20)

extension PhaseFourTests {

    func testTargetProgressResolvesDirection() {
        let losing = WeightMetrics.targetProgress(currentKg: 80, targetKg: 75)
        XCTAssertEqual(losing?.direction, .lose)
        XCTAssertEqual(losing?.remainingKg ?? .nan, 5, accuracy: 0.0001)
        XCTAssertFalse(losing?.isAtTarget ?? true)

        let gaining = WeightMetrics.targetProgress(currentKg: 70, targetKg: 75)
        XCTAssertEqual(gaining?.direction, .gain)
        XCTAssertEqual(gaining?.remainingKg ?? .nan, 5, accuracy: 0.0001)

        let arrived = WeightMetrics.targetProgress(currentKg: 75, targetKg: 75)
        XCTAssertEqual(arrived?.direction, .atTarget)
        XCTAssertEqual(arrived?.remainingKg, 0)
        XCTAssertTrue(arrived?.isAtTarget ?? false)
    }

    /// The distance is never negative, whichever way the user is heading — the
    /// direction belongs in the sentence, not in a minus sign next to someone's
    /// own body weight.
    func testTargetDistanceIsNeverNegative() {
        XCTAssertGreaterThanOrEqual(
            WeightMetrics.targetProgress(currentKg: 60, targetKg: 90)?.remainingKg ?? -1, 0
        )
        XCTAssertGreaterThanOrEqual(
            WeightMetrics.targetProgress(currentKg: 90, targetKg: 60)?.remainingKg ?? -1, 0
        )
    }

    /// Two weights that differ by less than half a gram are the same weight.
    func testTargetProgressHasATolerance() {
        let insideTolerance = WeightMetrics.targetProgress(currentKg: 75.0004, targetKg: 75)
        XCTAssertEqual(insideTolerance?.direction, .atTarget)

        let outsideTolerance = WeightMetrics.targetProgress(currentKg: 75.001, targetKg: 75)
        XCTAssertEqual(outsideTolerance?.direction, .lose)
        XCTAssertEqual(WeightTargetProgress.tolerance, 0.0005)
    }

    func testTargetProgressIsNilWhenEitherEndIsMissingOrUnusable() {
        XCTAssertNil(WeightMetrics.targetProgress(currentKg: nil, targetKg: 75))
        XCTAssertNil(WeightMetrics.targetProgress(currentKg: 80, targetKg: nil))
        XCTAssertNil(WeightMetrics.targetProgress(currentKg: 0, targetKg: 75))
        XCTAssertNil(WeightMetrics.targetProgress(currentKg: 80, targetKg: 0))
        XCTAssertNil(WeightMetrics.targetProgress(currentKg: -80, targetKg: 75))
    }

    /// Each direction names a whole sentence, so the view picks a phrasing
    /// rather than assembling one and getting the order wrong.
    func testTargetDirectionsHaveTheirOwnSentences() {
        XCTAssertEqual(WeightMetrics.targetProgress(currentKg: 80, targetKg: 75)?.descriptionKey, "weight_to_go_lose")
        XCTAssertEqual(WeightMetrics.targetProgress(currentKg: 70, targetKg: 75)?.descriptionKey, "weight_to_go_gain")
        XCTAssertEqual(WeightMetrics.targetProgress(currentKg: 75, targetKg: 75)?.descriptionKey, "weight_at_target")
    }
}

// MARK: - Body height storage (§16)

extension PhaseFourTests {

    func testHeightParseAcceptsPlainCommaAndWhitespace() {
        XCTAssertEqual(BodyHeight.parse("170"), 170)
        XCTAssertEqual(BodyHeight.parse("170.5"), 170.5)
        XCTAssertEqual(BodyHeight.parse("170,5"), 170.5)
        XCTAssertEqual(BodyHeight.parse("  170  "), 170)
        XCTAssertEqual(BodyHeight.parse("170.44"), 170.4)
    }

    func testHeightParseRefusesWhatTheCalculationRefuses() {
        XCTAssertNil(BodyHeight.parse(""))
        XCTAssertNil(BodyHeight.parse("   "))
        XCTAssertNil(BodyHeight.parse("abc"))
        XCTAssertNil(BodyHeight.parse("49"))
        XCTAssertNil(BodyHeight.parse("261"))
        XCTAssertNil(BodyHeight.parse("nan"))
        XCTAssertNil(BodyHeight.parse("inf"))
        XCTAssertNil(BodyHeight.parse("-170"))
    }

    func testHeightTextRoundTripsAndOmitsTrailingZero() {
        XCTAssertEqual(BodyHeight.text(170), "170")
        XCTAssertEqual(BodyHeight.text(170.5), "170.5")
        XCTAssertEqual(BodyHeight.text(nil), "")
        XCTAssertEqual(BodyHeight.text(0), "")
        XCTAssertEqual(BodyHeight.formatted(170), "170 cm")
        XCTAssertNil(BodyHeight.formatted(nil))
    }

    /// Storing then reading is the same number, and clearing really clears —
    /// including a height the calculation would refuse.
    func testHeightStoreRoundTripsAndClears() {
        BodyHeight.store(175)
        XCTAssertEqual(BodyHeight.storedCentimetres, 175)
        XCTAssertEqual(UserDefaults.standard.double(forKey: BodyHeight.storageKey), 175)

        BodyHeight.store(nil)
        XCTAssertNil(BodyHeight.storedCentimetres)
        XCTAssertNil(UserDefaults.standard.object(forKey: BodyHeight.storageKey))

        BodyHeight.store(300)
        XCTAssertNil(BodyHeight.storedCentimetres)
        XCTAssertNil(UserDefaults.standard.object(forKey: BodyHeight.storageKey))
    }

    /// A height written by an older build with a different rule must not be
    /// handed to the BMI formula just because it is present in UserDefaults.
    func testStoredHeightOutsideTheRangeReadsAsAbsent() {
        UserDefaults.standard.set(1700.0, forKey: BodyHeight.storageKey)
        XCTAssertNil(BodyHeight.storedCentimetres)
    }

    /// Everything that needs a height reads the same key.
    func testTheHeightKeyIsNamedInOnePlace() {
        UserDefaults.standard.set(180.0, forKey: BodyHeight.storageKey)
        XCTAssertEqual(BodyHeight.storedCentimetres, 180)
        XCTAssertEqual(WeightMetrics.formattedBMI(weightKg: 80, heightCm: BodyHeight.storedCentimetres), "24.7")
    }
}

// MARK: - Nutrition goal editing (§24, §25)

extension PhaseFourTests {

    func testGoalDraftTreatsBlankAndZeroAsCleared() {
        XCTAssertEqual(NutritionGoalDraft.parse("", for: .calories), .unset)
        XCTAssertEqual(NutritionGoalDraft.parse("   ", for: .calories), .unset)
        XCTAssertEqual(NutritionGoalDraft.parse("0", for: .calories), .unset)
        XCTAssertEqual(NutritionGoalDraft.parse("0.0", for: .protein), .unset)
    }

    func testGoalDraftReadsAUsableTarget() {
        XCTAssertEqual(NutritionGoalDraft.parse("2000", for: .calories), .value(2000))
        XCTAssertEqual(NutritionGoalDraft.parse("2000,5", for: .calories), .value(2000.5))
        XCTAssertEqual(NutritionGoalDraft.parse(" 150 ", for: .protein), .value(150))
    }

    func testGoalDraftRefusesNegativeNonFiniteAndAbsurd() {
        XCTAssertEqual(NutritionGoalDraft.parse("-1", for: .calories), .invalid)
        XCTAssertEqual(NutritionGoalDraft.parse("nan", for: .calories), .invalid)
        XCTAssertEqual(NutritionGoalDraft.parse("inf", for: .calories), .invalid)
        XCTAssertEqual(NutritionGoalDraft.parse("banana", for: .calories), .invalid)
        XCTAssertEqual(NutritionGoalDraft.parse("20001", for: .calories), .invalid)
        XCTAssertEqual(NutritionGoalDraft.parse("2001", for: .protein), .invalid)
        XCTAssertEqual(NutritionGoalDraft.parse("1001", for: .fiber), .invalid)
    }

    /// A save is all-or-nothing, and the editor is told which field was refused
    /// so it can point at it rather than failing silently.
    func testGoalDraftReportsEveryInvalidField() {
        let (goals, invalid) = NutritionGoalDraft.goals(
            calories: "2000",
            protein: "oops",
            carbs: "250",
            fat: "-5",
            fiber: "30"
        )
        XCTAssertNil(goals)
        XCTAssertEqual(invalid, [.protein, .fat])
    }

    func testGoalDraftBuildsAllFiveTargets() {
        let (goals, invalid) = NutritionGoalDraft.goals(
            calories: "2000",
            protein: "150",
            carbs: "250",
            fat: "70",
            fiber: "30"
        )
        XCTAssertTrue(invalid.isEmpty)
        XCTAssertEqual(goals?.calories, 2000)
        XCTAssertEqual(goals?.protein, 150)
        XCTAssertEqual(goals?.carbs, 250)
        XCTAssertEqual(goals?.fat, 70)
        XCTAssertEqual(goals?.fiber, 30)
    }

    func testGoalDraftClearsComponentsLeftBlank() {
        let (goals, invalid) = NutritionGoalDraft.goals(
            calories: "2000",
            protein: "",
            carbs: "",
            fat: "",
            fiber: ""
        )
        XCTAssertTrue(invalid.isEmpty)
        XCTAssertEqual(goals?.calories, 2000)
        XCTAssertNil(goals?.protein)
        XCTAssertNil(goals?.carbs)
        XCTAssertNil(goals?.fat)
        XCTAssertNil(goals?.fiber)
    }

    /// A goal worth exactly 2000 kcal should read back as "2000", not "2000.0".
    func testGoalTextOmitsATrailingZero() {
        XCTAssertEqual(NutritionGoalDraft.text(2000), "2000")
        XCTAssertEqual(NutritionGoalDraft.text(2000.5), "2000.5")
        XCTAssertEqual(NutritionGoalDraft.text(nil), "")
        XCTAssertEqual(NutritionGoalDraft.text(0), "")
        XCTAssertEqual(NutritionGoalDraft.text(-5), "")
    }

    /// The editor writes, the service reads: one round trip through the store.
    func testEditedGoalsReachTheServiceAndReadBack() throws {
        try nutrition.setGoals(DailyNutritionGoals(calories: 2000, protein: 150, carbs: 250, fat: 70, fiber: 30))

        let goals = try nutrition.goals()

        XCTAssertEqual(goals.calories, 2000)
        XCTAssertEqual(goals.protein, 150)
        XCTAssertEqual(goals.carbs, 250)
        XCTAssertEqual(goals.fat, 70)
        XCTAssertEqual(goals.fiber, 30)
    }

    /// Clearing a goal is a real edit, not a no-op, for the three columns that
    /// cannot hold NULL.
    func testClearingAGoalIsPersisted() throws {
        try nutrition.setGoals(DailyNutritionGoals(calories: 2000, protein: 150, carbs: 250, fat: 70, fiber: 30))
        try nutrition.setGoals(DailyNutritionGoals(calories: 1800, protein: nil, carbs: nil, fat: nil, fiber: nil))

        let goals = try nutrition.goals()

        XCTAssertEqual(goals.calories, 1800)
        XCTAssertNil(goals.protein)
        XCTAssertNil(goals.carbs)
        XCTAssertNil(goals.fat)
        XCTAssertNil(goals.fiber)
    }

    /// `Int32` columns cannot hold NULL, so a cleared goal is written as `0` and
    /// read back as "not set" — including a value that was never positive.
    func testAStoredZeroGoalReadsAsUnset() throws {
        try nutrition.setGoals(DailyNutritionGoals(calories: 0, protein: -10))

        let goals = try nutrition.goals()

        XCTAssertNil(goals.calories)
        XCTAssertNil(goals.protein)
    }

    func testGoalsRoundRatherThanTruncate() throws {
        try nutrition.setGoals(DailyNutritionGoals(calories: 2000.6, protein: 150.4))

        let goals = try nutrition.goals()

        XCTAssertEqual(goals.calories, 2001)
        XCTAssertEqual(goals.protein, 150)
    }

    /// Editing a goal changes what the Dashboard reads, with no second write.
    func testEditingAGoalChangesTheProgressTheDashboardSees() throws {
        let food = try makeFood("Test Bread", calories: 250)
        try log(food, grams: 100, on: Date())

        try nutrition.setGoals(DailyNutritionGoals(calories: 2000))
        XCTAssertEqual(try nutrition.goalProgress(on: Date(), calendar: calendar).calories.remaining, 1750)

        try nutrition.setGoals(DailyNutritionGoals(calories: 300))
        let after = try nutrition.goalProgress(on: Date(), calendar: calendar).calories
        XCTAssertEqual(after.target, 300)
        XCTAssertEqual(after.remaining, 50)
    }
}

// MARK: - Fitness goal (§25)

extension PhaseFourTests {

    /// The stored value is the stable English raw value. Translating the enum to
    /// Chinese must change the label and nothing else — a user who set "减脂"
    /// would otherwise lose their goal on the next launch.
    func testFitnessGoalRawValuesAreStable() {
        XCTAssertEqual(FitnessGoal.fatLoss.rawValue, "fatLoss")
        XCTAssertEqual(FitnessGoal.maintain.rawValue, "maintain")
        XCTAssertEqual(FitnessGoal.buildMuscle.rawValue, "buildMuscle")
    }

    func testFitnessGoalDoesNotDecodeFromDisplayText() {
        XCTAssertNil(FitnessGoal(rawValue: "减脂"))
        XCTAssertNil(FitnessGoal(rawValue: "Lose Fat"))
        XCTAssertNotNil(FitnessGoal(rawValue: "fatLoss"))
    }

    func testFitnessGoalStoreRoundTrips() {
        XCTAssertNil(FitnessGoal.stored)

        FitnessGoal.store(.buildMuscle)
        XCTAssertEqual(FitnessGoal.stored, .buildMuscle)
        XCTAssertEqual(UserDefaults.standard.string(forKey: FitnessGoal.storageKey), "buildMuscle")

        FitnessGoal.store(nil)
        XCTAssertNil(FitnessGoal.stored)
    }

    /// A value written by a newer build is one this build cannot name — not an
    /// error, and not a crash.
    func testAnUnknownStoredGoalReadsAsUnset() {
        UserDefaults.standard.set("recomposition", forKey: FitnessGoal.storageKey)
        XCTAssertNil(FitnessGoal.stored)
    }

    func testEveryFitnessGoalHasALabelKeyAndAnIcon() {
        for goal in FitnessGoal.allCases {
            XCTAssertTrue(goal.titleKey.hasPrefix("goal_"))
            XCTAssertFalse(goal.icon.isEmpty)
            XCTAssertNotEqual(goal.titleKey, goal.rawValue)
        }
    }
}

// MARK: - Amount and food validation (§14)

extension PhaseFourTests {

    /// An explicit zero on a food label is a fact about the food, not an absent
    /// entry — unlike a goal field, where zero means "clear it".
    func testFoodAmountTreatsExplicitZeroAsAValue() {
        XCTAssertEqual(FoodDraft.parseAmount("0", range: FoodDraft.macroRange), .value(0))
        XCTAssertEqual(FoodDraft.parseAmount("", range: FoodDraft.macroRange), .unset)
    }

    /// Calories are required by the model, so a blank field is zero — water is
    /// really zero — while a blank macro stays unknown.
    func testBlankCaloriesIsZeroAndBlankMacroIsUnknown() {
        XCTAssertEqual(FoodDraft.parseCalories(""), .value(0))
        XCTAssertEqual(FoodDraft.parseAmount("", range: FoodDraft.macroRange), .unset)
    }

    func testFoodAmountRefusesNegativeNonFiniteAndOutOfRange() {
        XCTAssertEqual(FoodDraft.parseAmount("-1", range: FoodDraft.macroRange), .invalid)
        XCTAssertEqual(FoodDraft.parseAmount("nan", range: FoodDraft.macroRange), .invalid)
        XCTAssertEqual(FoodDraft.parseAmount("inf", range: FoodDraft.macroRange), .invalid)
        XCTAssertEqual(FoodDraft.parseAmount("100.1", range: FoodDraft.macroRange), .invalid)
        XCTAssertEqual(FoodDraft.parseAmount("901", range: FoodDraft.calorieRange), .invalid)
        XCTAssertEqual(FoodDraft.parseAmount("900", range: FoodDraft.calorieRange), .value(900))
    }

    /// The amount eaten must be greater than zero — a zero-gram entry records
    /// nothing — and is capped so a unit mix-up cannot reach the store.
    func testGramsMustBePositiveAndBounded() {
        XCTAssertEqual(FoodDraft.parseGrams(""), .unset)
        XCTAssertEqual(FoodDraft.parseGrams("0"), .invalid)
        XCTAssertEqual(FoodDraft.parseGrams("-5"), .invalid)
        XCTAssertEqual(FoodDraft.parseGrams("nan"), .invalid)
        XCTAssertEqual(FoodDraft.parseGrams("inf"), .invalid)
        XCTAssertEqual(FoodDraft.parseGrams("120,5"), .value(120.5))
        XCTAssertEqual(FoodDraft.parseGrams("100000"), .value(100_000))
        XCTAssertEqual(FoodDraft.parseGrams("100001"), .invalid)
    }

    func testANameIsRequired() {
        XCTAssertNil(FoodDraft.parseName(""))
        XCTAssertNil(FoodDraft.parseName("   "))
        XCTAssertEqual(FoodDraft.parseName("  Oats  "), "Oats")
    }

    /// A pasted novel is truncated rather than stored whole.
    func testALongNameIsTruncated() {
        let long = String(repeating: "a", count: FoodDraft.maxNameLength + 40)
        XCTAssertEqual(FoodDraft.parseName(long)?.count, FoodDraft.maxNameLength)
    }

    /// A draft with no name is reported as such, and produces no template.
    func testADraftWithNoNameIsRefused() {
        let result = FoodDraft.result(from: .empty)
        XCTAssertTrue(result.nameIsMissing)
        XCTAssertNil(result.template)
        XCTAssertFalse(result.isValid)
    }

    /// A valid draft with blank macros keeps those macros unknown rather than
    /// recording them as zero.
    func testADraftKeepsUnlistedMacrosUnknown() {
        var draft = FoodDraft.Draft.empty
        draft.name = "Water"
        draft.calories = ""
        draft.protein = ""
        draft.carbs = ""
        draft.fat = ""
        draft.fiber = ""

        let result = FoodDraft.result(from: draft)

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.template?.name, "Water")
        XCTAssertEqual(result.template?.caloriesPer100g, 0)
        XCTAssertNil(result.template?.proteinPer100g)
        XCTAssertNil(result.template?.carbsPer100g)
        XCTAssertNil(result.template?.fatPer100g)
        XCTAssertNil(result.template?.fiberPer100g)
    }

    /// A declared zero survives as zero: a food with no fat is not a food whose
    /// fat content is unknown.
    func testADeclaredZeroMacroStaysZero() {
        var draft = FoodDraft.Draft.empty
        draft.name = "Lean Fish"
        draft.calories = "116"
        draft.protein = "25.5"
        draft.carbs = "0"
        draft.fat = "0.8"
        draft.fiber = "0"

        let result = FoodDraft.result(from: draft)

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.template?.carbsPer100g, 0)
        XCTAssertEqual(result.template?.fiberPer100g, 0)
    }

    /// One refused field refuses the whole food — a half-saved label would be
    /// worse than one not saved at all, because the user could not tell.
    func testOneBadFieldRefusesTheWholeDraft() {
        var draft = FoodDraft.Draft.empty
        draft.name = "Mystery Bar"
        draft.calories = "400"
        draft.protein = "20"
        draft.fiber = "101"

        let result = FoodDraft.result(from: draft)

        XCTAssertFalse(result.isValid)
        XCTAssertNil(result.template)
        XCTAssertEqual(result.invalidFields, ["fiber"])
    }

    /// The refused field is named by its nutrient, not by its goal. "Daily
    /// Calories" over a per-100 g label would read as a budget to fill in.
    func testRefusedFieldsAreNamedAsNutrients() {
        var draft = FoodDraft.Draft.empty
        draft.name = "Mystery Bar"
        draft.calories = "1000"

        let result = FoodDraft.result(from: draft)

        XCTAssertEqual(result.invalidFields, ["calories"])
        XCTAssertFalse(result.invalidFields.contains("daily_calorie_goal"))
    }

    func testACategoryIsOptional() {
        var draft = FoodDraft.Draft.empty
        draft.name = "Loose Apple"
        draft.calories = "52"
        draft.category = ""

        let result = FoodDraft.result(from: draft)

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.template?.category, "")
    }
}

// MARK: - Number formatting (§3)

extension PhaseFourTests {

    func testCaloriesAreWholeNumbers() {
        XCTAssertEqual(NutrientFormat.calories(1234.6), "1235")
        XCTAssertEqual(NutrientFormat.calories(0), "0")
        XCTAssertNil(NutrientFormat.calories(nil))
        XCTAssertNil(NutrientFormat.calories(.nan))
        XCTAssertNil(NutrientFormat.calories(.infinity))
    }

    /// The over-budget sentence supplies its own sign, so the magnitude must
    /// never carry one of its own.
    func testCalorieMagnitudeIsNeverNegative() {
        XCTAssertEqual(NutrientFormat.calorieMagnitude(-250), "250")
        XCTAssertEqual(NutrientFormat.calorieMagnitude(250), "250")
        XCTAssertEqual(NutrientFormat.calorieMagnitude(0), "0")
        XCTAssertNil(NutrientFormat.calorieMagnitude(nil))
    }

    /// One decimal: a total of 119.6 g must not read as a reached 120 g target.
    func testGramsKeepOneDecimal() {
        XCTAssertEqual(NutrientFormat.grams(120), "120.0")
        XCTAssertEqual(NutrientFormat.grams(119.6), "119.6")
        XCTAssertNil(NutrientFormat.grams(nil))
        XCTAssertNil(NutrientFormat.grams(.nan))
    }

    func testGramsWithUnitAppendsTheUnit() {
        XCTAssertEqual(NutrientFormat.gramsWithUnit(120), "120.0 g")
        XCTAssertNil(NutrientFormat.gramsWithUnit(nil))
    }
}

// MARK: - Range aggregation for the trend charts (§21–§23)

extension PhaseFourTests {

    /// The one-fetch range aggregation must agree with the per-day loop it
    /// replaces, day for day. If these ever disagree, the year chart is lying.
    func testRangeAggregationMatchesThePerDayLoop() throws {
        let food = try makeFood("Test Pasta", calories: 131, protein: 5, carbs: 25, fat: 1.1, fiber: 1.8)
        try log(food, grams: 100, slot: .breakfast, on: day(0))
        try log(food, grams: 200, slot: .lunch, on: day(2))
        try log(food, grams: 150, slot: .dinner, on: day(6))

        let batched = try nutrition.summaries(inRangeEndingOn: day(0), days: 7, calendar: calendar)
        let looped = try nutrition.summaries(endingOn: day(0), days: 7, calendar: calendar)

        XCTAssertEqual(batched.count, 7)
        XCTAssertEqual(looped.count, 7)

        for (index, pair) in zip(batched, looped).enumerated() {
            XCTAssertTrue(
                calendar.isDate(pair.0.date, inSameDayAs: pair.1.date),
                "day \(index) covers a different date"
            )
            XCTAssertEqual(pair.0.totals.calories, pair.1.totals.calories, accuracy: 0.001)
            XCTAssertEqual(pair.0.totals.protein, pair.1.totals.protein, accuracy: 0.001)
            XCTAssertEqual(pair.0.entryCount, pair.1.entryCount)
        }
    }

    /// Exactly the requested span, oldest first, empty days included — that is
    /// what a bar chart needs.
    func testRangeAggregationCoversTheWholeSpanOldestFirst() throws {
        let food = try makeFood("Test Rice", calories: 130)
        try log(food, grams: 100, on: day(2))

        let summaries = try nutrition.summaries(inRangeEndingOn: day(0), days: 30, calendar: calendar)

        XCTAssertEqual(summaries.count, 30)
        XCTAssertTrue(summaries[0].date < summaries[29].date)
        XCTAssertTrue(calendar.isDate(summaries[29].date, inSameDayAs: calendar.startOfDay(for: day(0))))
        XCTAssertEqual(summaries.filter { !$0.isEmpty }.count, 1)
        XCTAssertEqual(summaries[27].totals.calories, 130, accuracy: 0.001)
    }

    func testRangeAggregationOfZeroDaysIsEmpty() throws {
        XCTAssertTrue(try nutrition.summaries(inRangeEndingOn: day(0), days: 0, calendar: calendar).isEmpty)
    }

    /// The charts plot a gap as a gap. Zero calories is a real thing to record;
    /// nothing recorded is a different claim.
    func testANutritionSeriesLeavesUnloggedDaysNil() throws {
        let food = try makeFood("Test Yogurt", calories: 59)
        try log(food, grams: 100, on: day(0))

        let summaries = try nutrition.summaries(inRangeEndingOn: day(0), days: 3, calendar: calendar)
        let points = WeightMetrics.nutritionSeries(from: summaries, calendar: calendar)

        XCTAssertEqual(points.count, 3)
        XCTAssertNil(points[0].calories)
        XCTAssertNil(points[0].protein)
        XCTAssertFalse(points[0].hasValue)
        XCTAssertEqual(points[2].calories ?? .nan, 59, accuracy: 0.001)
        XCTAssertEqual(points[2].protein ?? .nan, 10, accuracy: 0.001)
    }

    /// A day that was logged and came to zero is a value, not a gap.
    func testADayLoggedAtZeroIsNotAGap() throws {
        let food = try makeFood("Test Water", calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0)
        try log(food, grams: 250, on: day(0))

        let summaries = try nutrition.summaries(inRangeEndingOn: day(0), days: 1, calendar: calendar)
        let points = WeightMetrics.nutritionSeries(from: summaries, calendar: calendar)

        XCTAssertEqual(points[0].calories, 0)
        XCTAssertTrue(points[0].hasValue)
    }

    func testNutritionSeriesIsEmptyForAnEmptyRange() {
        XCTAssertTrue(WeightMetrics.nutritionSeries(from: [], calendar: calendar).isEmpty)
    }
}

// MARK: - The food catalog: search, favourites, recents (§13)

extension PhaseFourTests {

    func testSearchMatchesASubstringCaseInsensitively() throws {
        try makeFood("Chicken Breast")
        try makeFood("Greek Yogurt")

        let hits = try nutrition.foods(matching: "chick")

        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.name, "Chicken Breast")
    }

    func testSearchWithNoMatchReturnsNothing() throws {
        try makeFood("Chicken Breast")
        XCTAssertTrue(try nutrition.foods(matching: "zzzz").isEmpty)
    }

    /// The picker's default order: favourites first, then most recently used,
    /// then alphabetical.
    func testFavouritesAreRankedFirstInSearch() throws {
        let plain = try makeFood("Apple")
        let favourite = try makeFood("Apricot")
        try nutrition.setFavorite(favourite, isFavorite: true)

        let hits = try nutrition.foods(matching: "Ap")

        XCTAssertEqual(hits.first?.name, "Apricot")
        XCTAssertTrue(hits.contains { $0.objectID == plain.objectID })
    }

    func testFavouriteFoodsAreAlphabetical() throws {
        let pear = try makeFood("Pear")
        let apple = try makeFood("Apple")
        let mango = try makeFood("Mango")
        for food in [pear, apple, mango] {
            try nutrition.setFavorite(food, isFavorite: true)
        }

        let favourites = try nutrition.favoriteFoods()

        XCTAssertEqual(favourites.map(\.name), ["Apple", "Mango", "Pear"])
    }

    func testUnfavouritingRemovesAFoodFromTheFavourites() throws {
        let apple = try makeFood("Apple")
        try nutrition.setFavorite(apple, isFavorite: true)
        XCTAssertEqual(try nutrition.favoriteFoods().count, 1)

        try nutrition.setFavorite(apple, isFavorite: false)

        XCTAssertTrue(try nutrition.favoriteFoods().isEmpty)
    }

    /// Recents are a sort, not a second table — and a food that has never been
    /// logged is not recently used.
    ///
    /// `lastUsed` is stamped explicitly rather than by calling `markUsed` twice:
    /// two calls land microseconds apart, and a sort on a tie would make this
    /// test's outcome depend on the machine.
    func testRecentsAreNewestFirstAndExcludeNeverUsed() throws {
        let neverUsed = try makeFood("Never Used")
        let older = try makeFood("Older")
        let newer = try makeFood("Newer")

        older.lastUsed = day(2)
        newer.lastUsed = day(0)
        try context.save()

        let recents = try nutrition.recentFoods(limit: 20)

        XCTAssertEqual(recents.map(\.name), ["Newer", "Older"])
        XCTAssertFalse(recents.contains { $0.objectID == neverUsed.objectID })
    }

    func testRecentsRespectTheLimit() throws {
        for index in 0..<5 {
            let food = try makeFood("Food \(index)")
            try nutrition.markUsed(food)
        }

        XCTAssertEqual(try nutrition.recentFoods(limit: 2).count, 2)
        XCTAssertTrue(try nutrition.recentFoods(limit: 0).isEmpty)
    }

    /// Recents are ordered by the stamp, so using a food again moves it to the
    /// front without any second table being written.
    func testUsingAFoodAgainMovesItToTheFrontOfRecents() throws {
        let first = try makeFood("First")
        let second = try makeFood("Second")

        first.lastUsed = day(1)
        second.lastUsed = day(0)
        try context.save()
        XCTAssertEqual(try nutrition.recentFoods(limit: 10).first?.name, "Second")

        // A fresh stamp, one day later than anything else in the store.
        first.lastUsed = calendar.date(byAdding: .day, value: 1, to: Date())
        try context.save()

        XCTAssertEqual(try nutrition.recentFoods(limit: 10).first?.name, "First")
    }

    /// A catalog row is not an Eckstein diet rule: an empty category keeps it
    /// out of the diet pickers, which match on `DietCategory` values.
    func testACatalogRowIsNotMistakenForADietRule() throws {
        let catalog = try makeFood("Chicken Breast", calories: 165)
        XCTAssertEqual(catalog.category, "")

        let dietRule = try nutrition.food(named: "Chicken Breast", category: nil)
        XCTAssertEqual(dietRule?.objectID, catalog.objectID)

        let otherCategory = try nutrition.food(named: "Chicken Breast", category: "Protein")
        XCTAssertNil(otherCategory)
    }

    func testBarcodeLookupFindsTheRowItWasWrittenWith() throws {
        let food = try nutrition.upsertFood(
            from: FoodTemplate(
                name: "Scanned Bar",
                category: "Snacks",
                barcode: "1234567890123",
                caloriesPer100g: 400,
                proteinPer100g: 20,
                carbsPer100g: 40,
                fatPer100g: 12,
                fiberPer100g: 5,
                brand: "Test",
                servingSize: 40,
                servingUnit: "g"
            ),
            source: .barcode
        )

        let found = try nutrition.food(matchingBarcode: "1234567890123")

        XCTAssertEqual(found?.objectID, food.objectID)
        XCTAssertNil(try nutrition.food(matchingBarcode: "0000000000000"))
        XCTAssertNil(try nutrition.food(matchingBarcode: "   "))
    }

    /// Scanning the same product twice updates one row rather than creating two.
    func testUpsertingABarcodeTwiceKeepsOneRow() throws {
        let template = FoodTemplate(
            name: "Scanned Bar",
            category: "Snacks",
            barcode: "9876543210987",
            caloriesPer100g: 400,
            proteinPer100g: 20,
            carbsPer100g: 40,
            fatPer100g: 12,
            fiberPer100g: 5,
            brand: "Test",
            servingSize: nil,
            servingUnit: nil
        )

        let first = try nutrition.upsertFood(from: template, source: .barcode)
        let second = try nutrition.upsertFood(from: template, source: .barcode)

        XCTAssertEqual(first.objectID, second.objectID)
        XCTAssertEqual(try nutrition.foods(matching: "Scanned Bar").count, 1)
    }
}

// MARK: - Logging, editing and deleting an entry (§10–§12)

extension PhaseFourTests {

    /// Logging the same food twice on one day merges into one row, which is what
    /// keeps "add again" from filling the log with duplicates.
    func testLoggingTheSameFoodTwiceMergesIntoOneEntry() throws {
        let food = try makeFood("Test Oats", calories: 100)
        try log(food, grams: 100, on: Date())
        try log(food, grams: 50, on: Date())

        let entries = try nutrition.entries(on: Date(), calendar: calendar)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.gramsConsumed, 150)
        // The snapshot is recomputed from the merged total, not left stale.
        XCTAssertEqual(entries.first?.calories?.doubleValue ?? .nan, 150, accuracy: 0.001)
    }

    /// Correcting the amount recomputes what the entry contributes, which is the
    /// whole point of the edit.
    func testEditingTheGramsRecomputesTheSnapshot() throws {
        let food = try makeFood("Test Pasta", calories: 131, protein: 5, carbs: 25, fat: 1.1, fiber: 1.8)
        let entry = try log(food, grams: 100, on: Date())
        XCTAssertEqual(entry.calories?.doubleValue ?? .nan, 131, accuracy: 0.001)

        try nutrition.updateGrams(250, for: entry)

        XCTAssertEqual(entry.gramsConsumed, 250)
        XCTAssertEqual(entry.calories?.doubleValue ?? .nan, 327.5, accuracy: 0.001)
        XCTAssertEqual(entry.protein?.doubleValue ?? .nan, 12.5, accuracy: 0.001)
    }

    /// Editing the amount changes the day's total with no second write and no
    /// stale cache left behind.
    func testEditingTheGramsUpdatesTheDayTotal() throws {
        let food = try makeFood("Test Rice", calories: 130)
        let entry = try log(food, grams: 100, on: Date())
        XCTAssertEqual(try nutrition.dailySummary(for: Date(), calendar: calendar).dailyCalories, 130, accuracy: 0.001)

        try nutrition.updateGrams(200, for: entry)

        XCTAssertEqual(try nutrition.dailySummary(for: Date(), calendar: calendar).dailyCalories, 260, accuracy: 0.001)
    }

    /// Deleting a row removes it from the day, unlocks its totals, and leaves
    /// the rest of the log alone.
    func testDeletingAnEntryUnlocksItsShareOfTheSummary() throws {
        let oats = try makeFood("Test Oats", calories: 100)
        let rice = try makeFood("Test Rice", calories: 130)
        let oatEntry = try log(oats, grams: 200, on: Date())
        try log(rice, grams: 100, on: Date())

        let before = try nutrition.dailySummary(for: Date(), calendar: calendar)
        XCTAssertEqual(before.dailyCalories, 330, accuracy: 0.001)
        XCTAssertEqual(before.entryCount, 2)

        try nutrition.delete(oatEntry)

        let after = try nutrition.dailySummary(for: Date(), calendar: calendar)
        XCTAssertEqual(after.dailyCalories, 130, accuracy: 0.001)
        XCTAssertEqual(after.entryCount, 1)
        XCTAssertEqual(try nutrition.entries(on: Date(), calendar: calendar).count, 1)
    }

    func testDeletingTheLastEntryLeavesAnEmptyDay() throws {
        let food = try makeFood("Test Banana", calories: 89)
        let entry = try log(food, grams: 118, on: Date())

        try nutrition.delete(entry)

        let summary = try nutrition.dailySummary(for: Date(), calendar: calendar)
        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.dailyCalories, 0)
        XCTAssertEqual(summary.entryCount, 0)
    }

    /// A copy is a new identity throughout — a fresh `id`, a fresh `objectID` —
    /// so the sync layer and the HealthKit dedupe key cannot confuse it with its
    /// source.
    func testDuplicateGetsItsOwnIdentityAndLeavesTheOriginalAlone() throws {
        let food = try makeFood("Test Salmon", calories: 208, protein: 20.4, carbs: 0, fat: 13.4, fiber: 0)
        let original = try log(food, grams: 150, on: Date())

        let copy = try nutrition.duplicate(original)

        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertNotEqual(copy.objectID, original.objectID)
        XCTAssertEqual(copy.foodName, original.foodName)
        XCTAssertEqual(copy.gramsConsumed, original.gramsConsumed)
        XCTAssertEqual(copy.calories?.doubleValue, original.calories?.doubleValue)
        // The original is untouched: two entries now exist for the day.
        XCTAssertEqual(try nutrition.entries(on: Date(), calendar: calendar).count, 2)
    }

    /// "Add again" is the ordinary log path, so it merges into the existing row
    /// for that food rather than creating a second one.
    func testLogAgainMergesIntoTheExistingEntry() throws {
        let food = try makeFood("Test Eggs", calories: 155)
        let entry = try log(food, grams: 100, on: Date())

        try nutrition.logAgain(entry)

        let entries = try nutrition.entries(on: Date(), calendar: calendar)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.gramsConsumed, 200)
    }

    /// Each slot gets its own meal row, which is the only reason the Diet
    /// screen's four sections can be told apart.
    func testEachSlotIsFiledUnderItsOwnMeal() throws {
        let food = try makeFood("Test Toast", calories: 250)
        try log(food, grams: 100, slot: .breakfast, on: Date())
        try log(food, grams: 50, slot: .snack, on: Date())

        let summary = try nutrition.dailySummary(for: Date(), calendar: calendar)

        XCTAssertEqual(summary.byMealType[.breakfast]?.calories ?? .nan, 250, accuracy: 0.001)
        XCTAssertEqual(summary.byMealType[.snack]?.calories ?? .nan, 125, accuracy: 0.001)
        XCTAssertEqual(summary.byMealType[.lunch]?.calories ?? .nan, 0, accuracy: 0.001)
        XCTAssertEqual(summary.dailyCalories, 375, accuracy: 0.001)
    }

    /// A pre-existing meal row keeps the slot it was recorded with; logging
    /// through the unspecified bucket must not relabel it.
    func testAnExistingMealsSlotIsNeverOverwritten() throws {
        let food = try makeFood("Test Yogurt", calories: 59)
        try log(food, grams: 100, slot: .breakfast, on: Date())

        try nutrition.logEntry(
            foodName: "Test Yogurt",
            category: food.category,
            grams: 100,
            mealNumber: MealType.unspecified.slotMealNumber,
            mealType: nil,
            date: Date(),
            food: food,
            calendar: calendar
        )

        let summary = try nutrition.dailySummary(for: Date(), calendar: calendar)
        XCTAssertEqual(summary.byMealType[.breakfast]?.calories ?? .nan, 118, accuracy: 0.001)
        XCTAssertEqual(summary.byMealType[.unspecified]?.calories ?? .nan, 0, accuracy: 0.001)
    }

    /// Without a slot the entry lands in the unspecified bucket and stays
    /// absent on the way back out, rather than claiming to be breakfast.
    func testANewEntryWithNoSlotStaysUnspecified() throws {
        let food = try makeFood("Test Tofu", calories: 76)
        try nutrition.logEntry(
            foodName: "Test Tofu",
            category: food.category,
            grams: 100,
            date: Date(),
            food: food,
            calendar: calendar
        )

        let summary = try nutrition.dailySummary(for: Date(), calendar: calendar)

        XCTAssertEqual(summary.byMealType[.unspecified]?.calories ?? .nan, 76, accuracy: 0.001)
        XCTAssertEqual(MealType.unspecified.storedValue, nil)
        XCTAssertEqual(MealType.unspecified.slotMealNumber, 1)
    }

    /// An entry whose food has no known values is "unknown", not zero.
    func testAnEntryWithNoKnownValuesReadsAsUnknown() throws {
        try nutrition.logEntry(
            foodName: "Unheard Of",
            category: nil,
            grams: 100,
            date: day(400),
            calendar: calendar
        )

        let entry = try XCTUnwrap(try nutrition.entries(on: day(400), calendar: calendar).first)

        XCTAssertNil(entry.calories)
        XCTAssertNil(entry.protein)
    }

    func testThePreviewMatchesWhatTheWriteStores() throws {
        let food = try makeFood("Test Quinoa", calories: 120, protein: 4.4, carbs: 21.3, fat: 1.9, fiber: 2.8)

        let preview = try XCTUnwrap(
            nutrition.snapshot(for: food, foodName: "Test Quinoa", category: food.category, grams: 185)
        )
        let entry = try log(food, grams: 185, on: Date())

        XCTAssertEqual(preview.calories, try XCTUnwrap(entry.calories).doubleValue, accuracy: 0.0001)
        XCTAssertEqual(preview.protein, try XCTUnwrap(entry.protein).doubleValue, accuracy: 0.0001)
        XCTAssertEqual(preview.carbs, try XCTUnwrap(entry.carbs).doubleValue, accuracy: 0.0001)
        XCTAssertEqual(preview.fat, try XCTUnwrap(entry.fat).doubleValue, accuracy: 0.0001)
        XCTAssertEqual(preview.fiber, try XCTUnwrap(entry.fiber).doubleValue, accuracy: 0.0001)
    }

    /// The preview falls back the same way the write does, so a diet-rule food
    /// with no catalog row still previews a real number instead of nothing —
    /// while a name with no rule stays "unknown" rather than becoming zero.
    func testThePreviewResolvesThroughTheSameFallbackAsTheWrite() throws {
        let documented = try XCTUnwrap(
            nutrition.snapshot(
                for: nil,
                foodName: "Chicken (No Skin)",
                category: "Protein (Non-Fat)",
                grams: 100
            )
        )
        XCTAssertEqual(documented.calories, 165, accuracy: 0.001)
        XCTAssertEqual(documented.protein, 31, accuracy: 0.001)

        // The rule is matched on name *and* category, so the same name filed
        // under another category is not a match.
        XCTAssertNil(
            nutrition.snapshot(for: nil, foodName: "Chicken (No Skin)", category: "Carbs", grams: 100)
        )
        XCTAssertNil(
            nutrition.snapshot(for: nil, foodName: "Something Nobody Wrote Down", category: nil, grams: 100)
        )
    }

    /// Days are separated by the calendar, not by comparing instants.
    func testEntriesAreScopedToOneDay() throws {
        let food = try makeFood("Test Apple", calories: 52)
        try log(food, grams: 182, slot: .breakfast, on: day(1))
        try log(food, grams: 100, slot: .breakfast, on: day(0))

        XCTAssertEqual(try nutrition.entries(on: day(1), calendar: calendar).count, 1)
        XCTAssertEqual(
            try nutrition.dailySummary(for: day(1), calendar: calendar).dailyCalories, 94.64, accuracy: 0.01
        )
        XCTAssertEqual(
            try nutrition.dailySummary(for: day(0), calendar: calendar).dailyCalories, 52, accuracy: 0.01
        )
    }
}

// MARK: - Meal slots (§5, §12)

extension PhaseFourTests {

    /// The four slots a user can pick, in the order the day reads.
    func testSelectableSlotsExcludeTheUnspecifiedBucket() {
        XCTAssertEqual(MealType.selectableCases, [.breakfast, .lunch, .dinner, .snack])
        XCTAssertFalse(MealType.selectableCases.contains(.unspecified))
    }

    /// Each slot owns a distinct meal number — otherwise every slot would share
    /// one meal row and the sections could not be told apart.
    func testEachSlotOwnsADistinctMealNumber() {
        let numbers = MealType.selectableCases.map(\.slotMealNumber)
        XCTAssertEqual(Set(numbers).count, MealType.selectableCases.count)
        XCTAssertEqual(numbers, [1, 2, 3, 4])
    }

    /// The stored value is the canonical string the remote CHECK constraint
    /// uses, and "no slot" round-trips as absent rather than as "unspecified".
    func testStoredValuesRoundTrip() {
        for slot in MealType.selectableCases {
            XCTAssertEqual(slot.storedValue, slot.rawValue)
            XCTAssertEqual(MealType(storedValue: slot.storedValue), slot)
        }
        XCTAssertNil(MealType.unspecified.storedValue)
        XCTAssertEqual(MealType(storedValue: nil), .unspecified)
        XCTAssertEqual(MealType(storedValue: "unspecified"), .unspecified)
        XCTAssertEqual(MealType(storedValue: "brunch"), .unspecified)
        XCTAssertEqual(MealType(storedValue: "LUNCH"), .lunch)
        XCTAssertEqual(MealType(storedValue: "  dinner  "), .dinner)
    }

    /// A missing or not-yet-translated table must fall back to the English
    /// label, never to the raw key.
    func testSlotLabelsNeverSurfaceTheKey() {
        for slot in MealType.allCases {
            XCTAssertFalse(slot.localizedName.hasPrefix("meal_"))
            XCTAssertFalse(slot.localizedName.isEmpty)
        }
    }

    // MARK: - English fallback for an incomplete translation (§2)

    /// Runs `body` with `language` active and puts the previous one back
    /// afterwards — even if `body` fails an assertion, because `defer` runs on
    /// the way out of a failed test too.
    ///
    /// `Bundle.setLanguage` writes to a global, so a test that did not restore
    /// it would change what every test after it in the run sees.
    private func withLanguage(_ language: String, _ body: () -> Void) {
        let previous = Bundle.currentLanguageBundle?.bundleURL
            .deletingPathExtension()
            .lastPathComponent
        Bundle.setLanguage(language)
        defer { Bundle.setLanguage(previous ?? "en") }
        body()
    }

    /// `dashboard_log_weight` is translated in `en` and in `zh-Hans`, and is one
    /// of the keys the Hebrew table does not carry — so it is exactly the case
    /// the fallback exists for.
    func testAMissingTranslationFallsBackToEnglishRatherThanTheKey() {
        let key = "dashboard_log_weight"
        withLanguage("he") {
            let localized = key.localized
            XCTAssertNotEqual(localized, key, "Hebrew has no entry, so the key itself came back")
            XCTAssertFalse(localized.isEmpty)
            XCTAssertFalse(localized.contains("_"), "that is not a sentence: \(localized)")
        }
    }

    /// And the fallback must not be reached when the active language does have
    /// the entry — a fallback that always won would leave every screen English,
    /// and would do it without raising anything.
    ///
    /// Asserted against the English string rather than against the expected
    /// Chinese: pinning the wording here would make the test fail on a
    /// translation edit that broke nothing.
    func testATranslatedStringStillWinsOverTheFallback() {
        let key = "dashboard_log_weight"
        var english = ""
        withLanguage("en") { english = key.localized }
        XCTAssertFalse(english.isEmpty)
        withLanguage("zh-Hans") {
            let localized = key.localized
            XCTAssertNotEqual(localized, key)
            XCTAssertNotEqual(localized, english, "the fallback overrode a table that has the entry")
        }
    }

    /// The parameterised overload has to fall back too, and to a string that is
    /// still a format — an English sentence handed back unformatted would put a
    /// literal `%@` on screen.
    func testTheFormatterAlsoFallsBackAndStillSubstitutes() {
        withLanguage("he") {
            let localized = "invalid_fields_named".localized("Protein")
            XCTAssertNotEqual(localized, "invalid_fields_named")
            XCTAssertFalse(localized.contains("%@"), "the format was returned unformatted")
            XCTAssertTrue(localized.contains("Protein"))
        }
    }

    /// A key no table anywhere carries is still returned as itself. The fallback
    /// searches a second set of tables, and a bug there would make every
    /// genuinely missing key look like a hit.
    func testTheFallbackLeavesAnUnknownKeyAlone() {
        let missing = "this_key_is_in_no_table_at_all"
        withLanguage("he") {
            XCTAssertEqual(missing.localized, missing)
            XCTAssertEqual(missing.localized("x"), missing)
        }
    }

    /// Every language the app ships resolves to its own bundle, and has an
    /// English bundle behind it to fall back to. Without the latter,
    /// `localizationBundles()` has nothing to fall back to and a missing key
    /// renders as the key again — the state this section exists to prevent.
    func testEveryShippedLanguageResolvesToABundleWithEnglishBehindIt() {
        XCTAssertNotNil(Bundle.englishLanguageBundle)
        for language in LocalizationManager.supportedLanguages {
            withLanguage(language) {
                XCTAssertNotNil(
                    Bundle.currentLanguageBundle,
                    "\(language) resolved to no bundle, so nothing is being localized"
                )
            }
        }
    }
}
