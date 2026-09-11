//
//  FitnessGoal.swift
//  Eckstein
//
//  The user's training intention: lose fat, maintain, or build muscle.
//
//  Separate from `NutritionGoal` in `NutritionCalculator`, which carries a
//  `custom(protein:carbs:fat:)` case and therefore has no raw type. That type is
//  used by the macro calculator and is left alone; this one exists to be stored
//  and displayed.
//
//  The raw values are the storage format and are **not** localized. `fatLoss`
//  stays `fatLoss` in every language — only `titleKey` is translated. Storing a
//  translated string would make the value unreadable to any other language the
//  user switches to, and would break the moment a translation was reworded.
//

import Foundation

enum FitnessGoal: String, CaseIterable, Identifiable {
    case fatLoss
    case maintain
    case buildMuscle

    var id: String { rawValue }

    /// The localization key for this goal's label. Never the raw value.
    var titleKey: String {
        switch self {
        case .fatLoss: return "goal_lose_fat"
        case .maintain: return "goal_maintain"
        case .buildMuscle: return "goal_build_muscle"
        }
    }

    var icon: String {
        switch self {
        case .fatLoss: return "arrow.down.circle"
        case .maintain: return "equal.circle"
        case .buildMuscle: return "arrow.up.circle"
        }
    }

    // MARK: - Storage

    static let storageKey = "fitnessGoal"

    /// The stored goal, or `nil` when none is set.
    ///
    /// An unrecognised stored value reads as unset rather than failing: a value
    /// written by a newer build is not an error, it is simply one this build
    /// cannot name.
    static var stored: FitnessGoal? {
        guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return nil }
        return FitnessGoal(rawValue: raw)
    }

    static func store(_ goal: FitnessGoal?) {
        if let goal {
            UserDefaults.standard.set(goal.rawValue, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }
}
