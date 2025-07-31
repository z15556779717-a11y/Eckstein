//
//  CDWorkoutSet+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//
//

import Foundation
import CoreData


extension CDWorkoutSet {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDWorkoutSet> {
        return NSFetchRequest<CDWorkoutSet>(entityName: "CDWorkoutSet")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var setNumber: Int32
    @NSManaged public var weightKg: Double
    @NSManaged public var reps: Int32
    @NSManaged public var targetReps: Int32
    @NSManaged public var completed: Bool
    @NSManaged public var notes: String?
    @NSManaged public var workout: CDWorkout?
    @NSManaged public var exercise: CDExercise?

}

extension CDWorkoutSet : Identifiable {

}