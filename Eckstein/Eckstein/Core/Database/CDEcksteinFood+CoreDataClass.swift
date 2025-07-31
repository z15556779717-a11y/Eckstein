//
//  CDEcksteinFood+CoreDataClass.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import Foundation
import CoreData

@objc(CDEcksteinFood)
public class CDEcksteinFood: NSManagedObject, Identifiable {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDEcksteinFood> {
        return NSFetchRequest<CDEcksteinFood>(entityName: "CDEcksteinFood")
    }
}