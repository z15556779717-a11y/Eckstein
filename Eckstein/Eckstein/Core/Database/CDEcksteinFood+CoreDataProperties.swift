//
//  CDEcksteinFood+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import Foundation
import CoreData

extension CDEcksteinFood {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var category: String?
    @NSManaged public var dailyGrams: Int32
    @NSManaged public var isFat: Bool
    @NSManaged public var isCustom: Bool
    @NSManaged public var createdAt: Date?
}