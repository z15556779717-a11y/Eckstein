//
//  CDFood+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//
//

import Foundation
import CoreData


extension CDFood {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDFood> {
        return NSFetchRequest<CDFood>(entityName: "CDFood")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var brand: String?
    @NSManaged public var barcode: String?
    @NSManaged public var caloriesPer100g: Int32
    @NSManaged public var proteinPer100g: Double
    @NSManaged public var carbsPer100g: Double
    @NSManaged public var fatPer100g: Double
    @NSManaged public var fiberPer100g: Double
    @NSManaged public var isCustom: Bool
    @NSManaged public var category: String?
    @NSManaged public var servingSize: Double
    @NSManaged public var servingUnit: String?
    @NSManaged public var lastUsed: Date?
    @NSManaged public var isFavorite: Bool
    @NSManaged public var isVerified: Bool
    @NSManaged public var mealItems: NSSet?

}

// MARK: Generated accessors for mealItems
extension CDFood {

    @objc(addMealItemsObject:)
    @NSManaged public func addToMealItems(_ value: CDMealItem)

    @objc(removeMealItemsObject:)
    @NSManaged public func removeFromMealItems(_ value: CDMealItem)

    @objc(addMealItems:)
    @NSManaged public func addToMealItems(_ values: NSSet)

    @objc(removeMealItems:)
    @NSManaged public func removeFromMealItems(_ values: NSSet)

}

extension CDFood : Identifiable {

}