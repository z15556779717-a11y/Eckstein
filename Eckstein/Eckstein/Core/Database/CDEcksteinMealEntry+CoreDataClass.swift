//
//  CDEcksteinMealEntry+CoreDataClass.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import Foundation
import CoreData

@objc(CDEcksteinMealEntry)
public class CDEcksteinMealEntry: NSManagedObject, Identifiable {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDEcksteinMealEntry> {
        return NSFetchRequest<CDEcksteinMealEntry>(entityName: "CDEcksteinMealEntry")
    }
}