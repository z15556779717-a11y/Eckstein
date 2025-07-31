//
//  CDEcksteinMeal+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import Foundation
import CoreData

extension CDEcksteinMeal {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var mealNumber: Int32
    @NSManaged public var isCarbLoad: Bool
    @NSManaged public var user: CDUser?
    @NSManaged public var entries: NSSet?
}

// MARK: Generated accessors for entries
extension CDEcksteinMeal {
    @objc(addEntriesObject:)
    @NSManaged public func addToEntries(_ value: CDEcksteinMealEntry)

    @objc(removeEntriesObject:)
    @NSManaged public func removeFromEntries(_ value: CDEcksteinMealEntry)

    @objc(addEntries:)
    @NSManaged public func addToEntries(_ values: NSSet)

    @objc(removeEntries:)
    @NSManaged public func removeFromEntries(_ values: NSSet)
}