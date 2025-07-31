//
//  CDMealItem+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//
//

import Foundation
import CoreData


extension CDMealItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDMealItem> {
        return NSFetchRequest<CDMealItem>(entityName: "CDMealItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var quantityGrams: Double
    @NSManaged public var meal: CDMeal?
    @NSManaged public var food: CDFood?

}