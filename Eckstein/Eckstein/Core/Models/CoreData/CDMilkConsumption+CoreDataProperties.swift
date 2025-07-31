//
//  CDMilkConsumption+CoreDataProperties.swift
//  Eckstein
//
//  Created by Assistant on 16/01/2025.
//
//

import Foundation
import CoreData


extension CDMilkConsumption {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDMilkConsumption> {
        return NSFetchRequest<CDMilkConsumption>(entityName: "CDMilkConsumption")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var amount: Double
    @NSManaged public var date: Date?
    @NSManaged public var syncStatus: String?
    @NSManaged public var user: CDUser?

}

extension CDMilkConsumption : Identifiable {

}