//
//  CDUserPreferences+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//
//

import Foundation
import CoreData


extension CDUserPreferences {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDUserPreferences> {
        return NSFetchRequest<CDUserPreferences>(entityName: "CDUserPreferences")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var dailyCalorieGoal: Int32
    @NSManaged public var dailyProteinGoal: Int32
    @NSManaged public var dailyCarbGoal: Int32
    @NSManaged public var weightUnit: String?
    @NSManaged public var heightCm: Int32
    @NSManaged public var activityLevel: String?
    @NSManaged public var dietStartDate: Date?
    @NSManaged public var startingWeight: Double
    @NSManaged public var preferredTheme: String?
    @NSManaged public var preferredAccentColor: String?
    @NSManaged public var user: CDUser?

}

extension CDUserPreferences : Identifiable {

}