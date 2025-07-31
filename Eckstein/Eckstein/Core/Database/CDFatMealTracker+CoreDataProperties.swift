//
//  CDFatMealTracker+CoreDataProperties.swift
//  Eckstein
//
//  Created by Assistant on 17/01/2025.
//

import Foundation
import CoreData

extension CDFatMealTracker {
    @NSManaged public var id: UUID?
    @NSManaged public var weekStartDate: Date?
    @NSManaged public var fatMealsConsumed: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncStatus: String?
    @NSManaged public var remoteId: UUID?
    @NSManaged public var user: CDUser?
}