//
//  CDWeightEntry+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//
//

import Foundation
import CoreData


extension CDWeightEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDWeightEntry> {
        return NSFetchRequest<CDWeightEntry>(entityName: "CDWeightEntry")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var weightKg: Double
    @NSManaged public var date: Date?
    @NSManaged public var source: String?
    @NSManaged public var syncStatus: String?
    @NSManaged public var bodyFatPercentage: Double
    @NSManaged public var muscleMass: Double
    @NSManaged public var notes: String?
    @NSManaged public var photoPath: String?
    @NSManaged public var user: CDUser?

}

extension CDWeightEntry : Identifiable {
    
    var bmi: Double? {
        let userHeight = UserDefaults.standard.double(forKey: "userHeightCm")
        guard userHeight > 0 else { return nil }
        
        let heightM = userHeight / 100.0
        return weightKg / (heightM * heightM)
    }
    
    var formattedWeight: String {
        String(format: "%.1f", weightKg)
    }
    
    var formattedDate: String {
        guard let date = date else { return "" }
        
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "Today, h:mm a"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "Yesterday, h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        
        return formatter.string(from: date)
    }
}