//
//  ExerciseCatalogSeed.swift
//  Eckstein
//
//  Fills the exercise library on first launch.
//

import CoreData
import Foundation

/// Puts the built-in movements into an empty library.
///
/// Shaped after `NutritionCatalogSeed`: idempotent, counted, and safe to call on
/// every launch. The differences are all about what "already seeded" can mean
/// here — see `seedIfNeeded`.
enum ExerciseCatalogSeed {

    /// Inserts whichever templates the library does not already have, and
    /// returns how many rows were written.
    ///
    /// `0` on every launch after the first, which is the normal case.
    ///
    /// **A row is matched by name, case-insensitively, and never deleted.** The
    /// two obvious markers do not work here. There is no `source` column as the
    /// nutrition catalog has, and `isCustom` cannot stand in for one: it defaults
    /// to `false` in `createExercise`, so an existing user who made their own
    /// movements before this seed existed would look fully seeded and get an
    /// empty library forever. Matching on name answers the question the brief
    /// actually asks — "does this movement already exist?" — so a user with
    /// their own "Squat" gets no second one, and a user who deletes a movement
    /// they never use does not get it back one launch at a time.
    @discardableResult
    static func seedIfNeeded(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    ) throws -> Int {
        let existing = try existingNames(context: context)
        let missing = ExerciseData.exercises.filter { !existing.contains($0.name.lowercased()) }
        guard !missing.isEmpty else { return 0 }

        for template in missing {
            let exercise = CDExercise(context: context)
            exercise.id = UUID()
            exercise.name = template.name
            exercise.muscleGroup = template.muscleGroup
            exercise.category = template.category
            exercise.equipment = template.equipment
            // Not custom: these are the app's own movements, and the library
            // shows both kinds side by side.
            exercise.isCustom = false
            exercise.createdAt = Date()
        }

        try context.save()
        return missing.count
    }

    /// Every exercise name in the store, lowercased.
    ///
    /// One fetch rather than fifteen `count` queries: the library is small, and
    /// this keeps the whole decision in a single round trip.
    private static func existingNames(context: NSManagedObjectContext) throws -> Set<String> {
        let request: NSFetchRequest<CDExercise> = CDExercise.fetchRequest()
        return Set(
            try context.fetch(request)
                .compactMap { $0.name?.lowercased() }
        )
    }
}
