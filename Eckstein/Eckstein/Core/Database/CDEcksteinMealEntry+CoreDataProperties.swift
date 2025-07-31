//
//  CDEcksteinMealEntry+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import Foundation
import CoreData

extension CDEcksteinMealEntry {
    @NSManaged public var id: UUID?
    @NSManaged public var foodName: String?
    @NSManaged public var category: String?
    @NSManaged public var gramsConsumed: Int32
    @NSManaged public var meal: CDEcksteinMeal?
}