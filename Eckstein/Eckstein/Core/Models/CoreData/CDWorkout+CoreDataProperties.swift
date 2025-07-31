//
//  CDWorkout+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//
//

import Foundation
import CoreData


extension CDWorkout {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDWorkout> {
        return NSFetchRequest<CDWorkout>(entityName: "CDWorkout")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var date: Date?
    @NSManaged public var durationMinutes: Int32
    @NSManaged public var notes: String?
    @NSManaged public var completed: Bool
    @NSManaged public var syncStatus: String?
    @NSManaged public var user: CDUser?
    @NSManaged public var sets: NSSet?
    @NSManaged public var workoutType: CDWorkoutType?

}

// MARK: Generated accessors for sets
extension CDWorkout {

    @objc(addSetsObject:)
    @NSManaged public func addToSets(_ value: CDWorkoutSet)

    @objc(removeSetsObject:)
    @NSManaged public func removeFromSets(_ value: CDWorkoutSet)

    @objc(addSets:)
    @NSManaged public func addToSets(_ values: NSSet)

    @objc(removeSets:)
    @NSManaged public func removeFromSets(_ values: NSSet)

}

extension CDWorkout : Identifiable {

}