//
//  CDCalorieBank+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//
//

import Foundation
import CoreData


extension CDCalorieBank {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDCalorieBank> {
        return NSFetchRequest<CDCalorieBank>(entityName: "CDCalorieBank")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var caloriesSaved: Int32
    @NSManaged public var syncStatus: String?
    @NSManaged public var user: CDUser?
    @NSManaged public var foodName: String?

}

extension CDCalorieBank : Identifiable {

}