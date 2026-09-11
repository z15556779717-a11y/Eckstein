//
//  NutritionSnapshot.swift
//  Eckstein
//
//  A value-typed set of nutrition amounts, and the per-100 g maths that turns a
//  food's declared values plus a gram amount into one.
//
//  See NUTRITION_MIGRATION_PLAN.md §5 and §7.
//

import Foundation

/// Calories and macronutrients, in the units the app displays: kcal, grams.
///
/// Deliberately a plain value with no `NSManagedObject` in it, so the
/// aggregation layer is unit-testable without a store.
struct NutritionSnapshot: Equatable, Codable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double

    init(
        calories: Double = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        fiber: Double = 0
    ) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
    }

    /// All zero. The identity element for `+`, and what an empty day sums to.
    static let zero = NutritionSnapshot()

    /// Whether every component is zero.
    var isZero: Bool {
        calories == 0 && protein == 0 && carbs == 0 && fat == 0 && fiber == 0
    }

    /// Energy from the macros that carry it (protein and carbs 4 kcal/g, fat
    /// 9 kcal/g). Useful for sanity-checking a catalog entry; not used for
    /// display totals, which come from the declared calorie value.
    var caloriesFromMacros: Double {
        protein * 4 + carbs * 4 + fat * 9
    }

    static func + (lhs: NutritionSnapshot, rhs: NutritionSnapshot) -> NutritionSnapshot {
        NutritionSnapshot(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat,
            fiber: lhs.fiber + rhs.fiber
        )
    }

    static func += (lhs: inout NutritionSnapshot, rhs: NutritionSnapshot) {
        lhs = lhs + rhs
    }
}

extension NutritionSnapshot {
    /// The nutrition in `grams` of a food whose values are declared per 100 g.
    ///
    /// Returns `nil` when **every** input is `nil` — a food with no declared
    /// values contributes nothing, rather than a misleading all-zero snapshot
    /// that would be indistinguishable from a genuinely zero-calorie entry.
    /// Individual `nil` components are read as zero so the result stays additive.
    /// Whether an entry has nutrition at all is recorded separately, by the
    /// `CDEcksteinMealEntry` snapshot columns being `nil`.
    static func per100g(
        calories: Double?,
        protein: Double?,
        carbs: Double?,
        fat: Double?,
        fiber: Double?,
        grams: Double
    ) -> NutritionSnapshot? {
        guard calories != nil || protein != nil || carbs != nil || fat != nil || fiber != nil else {
            return nil
        }

        let multiplier = grams / 100.0
        return NutritionSnapshot(
            calories: (calories ?? 0) * multiplier,
            protein: (protein ?? 0) * multiplier,
            carbs: (carbs ?? 0) * multiplier,
            fat: (fat ?? 0) * multiplier,
            fiber: (fiber ?? 0) * multiplier
        )
    }

    /// These per-100 g values scaled to `grams`.
    ///
    /// The inverse of `per100g(calories:protein:carbs:fat:fiber:grams:)`: that
    /// builds a snapshot from optional per-100 g inputs, this rescales a snapshot
    /// that is already per-100 g. Used for the diet-rule fixture, whose values
    /// are known per 100 g and are not optional.
    func scaled(toGrams grams: Double) -> NutritionSnapshot {
        let multiplier = grams / 100.0
        return NutritionSnapshot(
            calories: calories * multiplier,
            protein: protein * multiplier,
            carbs: carbs * multiplier,
            fat: fat * multiplier,
            fiber: fiber * multiplier
        )
    }
}
