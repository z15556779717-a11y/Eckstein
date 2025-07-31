//
//  CDEcksteinMeal+CoreDataClass.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import Foundation
import CoreData

@objc(CDEcksteinMeal)
public class CDEcksteinMeal: NSManagedObject, Identifiable {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDEcksteinMeal> {
        return NSFetchRequest<CDEcksteinMeal>(entityName: "CDEcksteinMeal")
    }
}