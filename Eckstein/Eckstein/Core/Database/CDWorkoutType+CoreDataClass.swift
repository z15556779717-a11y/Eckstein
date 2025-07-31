//
//  CDWorkoutType+CoreDataClass.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import Foundation
import CoreData

@objc(CDWorkoutType)
public class CDWorkoutType: NSManagedObject, Identifiable {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDWorkoutType> {
        return NSFetchRequest<CDWorkoutType>(entityName: "CDWorkoutType")
    }
}