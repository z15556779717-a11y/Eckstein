//
//  CDWorkoutTypeExercise+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import Foundation
import CoreData

extension CDWorkoutTypeExercise {
    @NSManaged public var id: UUID?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var targetSets: Int32
    @NSManaged public var targetReps: Int32
    @NSManaged public var exercise: CDExercise?
    @NSManaged public var workoutType: CDWorkoutType?
}