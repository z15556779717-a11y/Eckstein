//
//  CDWorkoutTypeExercise+CoreDataClass.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import Foundation
import CoreData

@objc(CDWorkoutTypeExercise)
public class CDWorkoutTypeExercise: NSManagedObject, Identifiable {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDWorkoutTypeExercise> {
        return NSFetchRequest<CDWorkoutTypeExercise>(entityName: "CDWorkoutTypeExercise")
    }
}