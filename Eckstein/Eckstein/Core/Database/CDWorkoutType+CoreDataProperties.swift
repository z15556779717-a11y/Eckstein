//
//  CDWorkoutType+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import Foundation
import CoreData

extension CDWorkoutType {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var lastUsed: Date?
    @NSManaged public var exercises: NSSet?
    @NSManaged public var user: CDUser?
    @NSManaged public var workouts: NSSet?
}

// MARK: Generated accessors for exercises
extension CDWorkoutType {
    @objc(addExercisesObject:)
    @NSManaged public func addToExercises(_ value: CDWorkoutTypeExercise)

    @objc(removeExercisesObject:)
    @NSManaged public func removeFromExercises(_ value: CDWorkoutTypeExercise)

    @objc(addExercises:)
    @NSManaged public func addToExercises(_ values: NSSet)

    @objc(removeExercises:)
    @NSManaged public func removeFromExercises(_ values: NSSet)
}

// MARK: Generated accessors for workouts
extension CDWorkoutType {
    @objc(addWorkoutsObject:)
    @NSManaged public func addToWorkouts(_ value: CDWorkout)

    @objc(removeWorkoutsObject:)
    @NSManaged public func removeFromWorkouts(_ value: CDWorkout)

    @objc(addWorkouts:)
    @NSManaged public func addToWorkouts(_ values: NSSet)

    @objc(removeWorkouts:)
    @NSManaged public func removeFromWorkouts(_ values: NSSet)
}