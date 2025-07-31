//
//  CDCarbLoadTracker+CoreDataProperties.swift
//  Eckstein
//
//  Created by Assistant on 17/01/2025.
//

import Foundation
import CoreData

extension CDCarbLoadTracker {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDCarbLoadTracker> {
        return NSFetchRequest<CDCarbLoadTracker>(entityName: "CDCarbLoadTracker")
    }

    @NSManaged public var carbLoadDate: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var remoteId: UUID?
    @NSManaged public var syncStatus: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var weekStartDate: Date?
    @NSManaged public var user: CDUser?

}