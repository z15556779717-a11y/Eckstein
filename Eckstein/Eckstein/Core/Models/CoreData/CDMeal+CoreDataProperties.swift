//
//  CDMeal+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//
//

import Foundation
import CoreData


extension CDMeal {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDMeal> {
        return NSFetchRequest<CDMeal>(entityName: "CDMeal")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var mealType: String?
    @NSManaged public var user: CDUser?
    @NSManaged public var items: NSSet?

}

// MARK: Generated accessors for items
extension CDMeal {

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: CDMealItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: CDMealItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)

}