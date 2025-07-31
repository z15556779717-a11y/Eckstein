//
//  WeightTests.swift
//  EcksteinTests
//
//  Created by Eliad Shahar on 13/07/2025.
//

import XCTest
import CoreData
@testable import Eckstein

class WeightTests: XCTestCase {
    var controller: PersistenceController!
    var context: NSManagedObjectContext!
    var repository: WeightRepository!
    
    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        repository = WeightRepository(context: context)
        
        // Set default user height for BMI calculations
        UserDefaults.standard.set(175.0, forKey: "userHeightCm")
    }
    
    override func tearDown() {
        controller = nil
        context = nil
        repository = nil
        UserDefaults.standard.removeObject(forKey: "userHeightCm")
        super.tearDown()
    }
    
    // MARK: - Weight Entry Tests
    
    func testCreateWeightEntry() {
        let entry = repository.createWeightEntry(
            weight: 75.5,
            date: Date(),
            notes: "Morning weight",
            source: "manual"
        )
        
        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.weightKg, 75.5)
        XCTAssertEqual(entry.source, "manual")
        XCTAssertEqual(entry.notes, "Morning weight")
    }
    
    func testScaleWeightEntry() async {
        let entry = await repository.addEntry(
            weight: 165.5,
            unit: .lbs,
            source: "Xiaomi Scale",
            notes: "Automated from scale"
        )
        
        XCTAssertEqual(entry.source, "Xiaomi Scale")
        XCTAssertEqual(entry.weightKg, 75.07, accuracy: 0.01) // 165.5 lbs = ~75.07 kg
    }
    
    // MARK: - BMI Calculation Tests
    
    func testBMICalculation() {
        let bmi = repository.calculateBMI(weight: 75, heightCm: 175)
        XCTAssertEqual(bmi, 24.49, accuracy: 0.01)
        
        let category = repository.getBMICategory(bmi)
        XCTAssertEqual(category, "Normal")
    }
    
    func testBMICategories() {
        let testCases: [(Double, String)] = [
            (16.0, "Underweight"),
            (18.5, "Normal"),
            (24.9, "Normal"),
            (25.0, "Overweight"),
            (29.9, "Overweight"),
            (30.0, "Obese"),
            (35.0, "Obese")
        ]
        
        for (bmi, expectedCategory) in testCases {
            let category = repository.getBMICategory(bmi)
            XCTAssertEqual(category, expectedCategory)
        }
    }
    
    // MARK: - Goal Management Tests
    
    func testGoalSetting() {
        repository.setGoalWeight(70.0)
        repository.setGoalDate(Date().addingTimeInterval(90 * 24 * 60 * 60)) // 90 days
        
        XCTAssertEqual(repository.goalWeight, 70.0)
        XCTAssertNotNil(repository.getGoalDate())
    }
    
    func testProgressCalculation() {
        // Create weight entries
        _ = repository.createWeightEntry(weight: 80.0, date: Date().addingTimeInterval(-30 * 24 * 60 * 60))
        _ = repository.createWeightEntry(weight: 75.0, date: Date())
        
        repository.setGoalWeight(70.0)
        
        let progress = repository.getProgressToGoal()
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress!, 50.0) // Lost 5kg out of 10kg goal = 50%
    }
    
    // MARK: - Statistics Tests
    
    func testWeeklyAverage() {
        let weights = [75.0, 74.8, 75.2, 74.9, 75.1, 74.7, 74.8]
        
        for (index, weight) in weights.enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: -index, to: Date())!
            _ = repository.createWeightEntry(weight: weight, date: date)
        }
        
        let average = repository.getWeeklyAverage()
        XCTAssertNotNil(average)
        XCTAssertEqual(average!, 74.93, accuracy: 0.01)
    }
    
    func testWeightTrend() {
        // Create descending weight entries (losing weight)
        let startDate = Date()
        for i in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: startDate)!
            let weight = 80.0 - Double(i) * 0.2 // Losing 0.2kg per day
            _ = repository.createWeightEntry(weight: weight, date: date)
        }
        
        let trend = repository.getWeightTrend()
        XCTAssertEqual(trend, .losing)
    }
    
    func testWeightChange() {
        // Add two entries a week apart
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        _ = repository.createWeightEntry(weight: 75.0, date: lastWeek)
        _ = repository.createWeightEntry(weight: 74.0, date: Date())
        
        let weeklyChange = repository.getWeeklyChange()
        XCTAssertNotNil(weeklyChange)
        XCTAssertEqual(weeklyChange!, -1.0) // Lost 1kg
    }
    
    // MARK: - Date Range Tests
    
    func testDateRangeFiltering() {
        // Create entries across different time periods
        let dates = [
            Calendar.current.date(byAdding: .day, value: -1, to: Date())!,    // Yesterday
            Calendar.current.date(byAdding: .day, value: -8, to: Date())!,    // Last week
            Calendar.current.date(byAdding: .day, value: -32, to: Date())!,   // Last month
            Calendar.current.date(byAdding: .month, value: -4, to: Date())!,  // 4 months ago
            Calendar.current.date(byAdding: .year, value: -2, to: Date())!    // 2 years ago
        ]
        
        for (index, date) in dates.enumerated() {
            _ = repository.createWeightEntry(weight: 75.0 + Double(index), date: date)
        }
        
        let weekEntries = repository.fetchWeightEntries(for: .week)
        let monthEntries = repository.fetchWeightEntries(for: .month)
        let yearEntries = repository.fetchWeightEntries(for: .year)
        let allEntries = repository.fetchWeightEntries(for: .all)
        
        XCTAssertEqual(weekEntries.count, 1)  // Only yesterday
        XCTAssertEqual(monthEntries.count, 2) // Yesterday and last week
        XCTAssertEqual(yearEntries.count, 4)  // All except 2 years ago
        XCTAssertEqual(allEntries.count, 5)   // All entries
    }
    
    // MARK: - Export Tests
    
    func testCSVExport() {
        // Create test data
        _ = repository.createWeightEntry(weight: 75.0, date: Date(), notes: "Test entry")
        _ = repository.createWeightEntry(weight: 74.5, date: Date().addingTimeInterval(-86400))
        
        let csvURL = repository.exportToCSV()
        XCTAssertNotNil(csvURL)
        
        if let url = csvURL {
            let csvContent = try? String(contentsOf: url)
            XCTAssertNotNil(csvContent)
            XCTAssertTrue(csvContent?.contains("75.0") ?? false)
            XCTAssertTrue(csvContent?.contains("Test entry") ?? false)
        }
    }
    
    func testJSONExport() {
        // Create test data
        _ = repository.createWeightEntry(
            weight: 75.0,
            date: Date(),
            bodyFatPercentage: 18.5,
            muscleMass: 32.0,
            source: "Xiaomi Scale"
        )
        
        let jsonURL = repository.exportToJSON(includeBodyComposition: true)
        XCTAssertNotNil(jsonURL)
        
        if let url = jsonURL,
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            XCTAssertNotNil(json["exportDate"])
            XCTAssertEqual(json["entriesCount"] as? Int, 1)
            
            if let entries = json["entries"] as? [[String: Any]],
               let firstEntry = entries.first {
                XCTAssertEqual(firstEntry["weightKg"] as? Double, 75.0)
                XCTAssertEqual(firstEntry["source"] as? String, "Xiaomi Scale")
                XCTAssertEqual(firstEntry["bodyFatPercentage"] as? Double, 18.5)
            }
        }
    }
    
    // MARK: - Best Weigh-In Time Tests
    
    func testBestWeighInTime() {
        // Create entries at different times
        let times = [6, 7, 7, 8, 7, 9, 7] // Mostly morning (7 AM)
        
        for (index, hour) in times.enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: -index, to: Date())!
            let components = DateComponents(hour: hour, minute: 0)
            let dateWithTime = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
            _ = repository.createWeightEntry(weight: 75.0, date: dateWithTime)
        }
        
        let bestTime = repository.getBestWeighInTime()
        XCTAssertEqual(bestTime, "Morning")
    }
    
    // MARK: - Data Deletion Tests
    
    func testDeleteEntry() {
        let entry = repository.createWeightEntry(weight: 75.0)
        let entryId = entry.id
        
        repository.delete(entry)
        
        let entries = repository.weightEntries
        XCTAssertFalse(entries.contains { $0.id == entryId })
    }
    
    func testDeleteAllData() {
        // Create multiple entries
        for i in 0..<5 {
            _ = repository.createWeightEntry(weight: 75.0 + Double(i))
        }
        
        XCTAssertEqual(repository.weightEntries.count, 5)
        
        repository.deleteAllData()
        
        XCTAssertEqual(repository.weightEntries.count, 0)
        XCTAssertNil(repository.currentWeight)
    }
}