//
//  CDExercise+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//
//

import Foundation
import CoreData


extension CDExercise {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDExercise> {
        return NSFetchRequest<CDExercise>(entityName: "CDExercise")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var category: String?
    @NSManaged public var muscleGroup: String?
    @NSManaged public var equipment: String?
    @NSManaged public var isCustom: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var youtubeLink: String?
    @NSManaged public var imageData: Data?
    @NSManaged public var workoutSets: NSSet?
    @NSManaged public var workoutTypeExercises: NSSet?

}

// MARK: Generated accessors for workoutSets
extension CDExercise {

    @objc(addWorkoutSetsObject:)
    @NSManaged public func addToWorkoutSets(_ value: CDWorkoutSet)

    @objc(removeWorkoutSetsObject:)
    @NSManaged public func removeFromWorkoutSets(_ value: CDWorkoutSet)

    @objc(addWorkoutSets:)
    @NSManaged public func addToWorkoutSets(_ values: NSSet)

    @objc(removeWorkoutSets:)
    @NSManaged public func removeFromWorkoutSets(_ values: NSSet)

}

// MARK: Generated accessors for workoutTypeExercises
extension CDExercise {

    @objc(addWorkoutTypeExercisesObject:)
    @NSManaged public func addToWorkoutTypeExercises(_ value: CDWorkoutTypeExercise)

    @objc(removeWorkoutTypeExercisesObject:)
    @NSManaged public func removeFromWorkoutTypeExercises(_ value: CDWorkoutTypeExercise)

    @objc(addWorkoutTypeExercises:)
    @NSManaged public func addToWorkoutTypeExercises(_ values: NSSet)

    @objc(removeWorkoutTypeExercises:)
    @NSManaged public func removeFromWorkoutTypeExercises(_ values: NSSet)

}

extension CDExercise : Identifiable {

}