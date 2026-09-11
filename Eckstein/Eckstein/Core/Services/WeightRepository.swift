//
//  WeightRepository.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import CoreData
import Combine
import SwiftUI

class WeightRepository: ObservableObject {
    static let shared = WeightRepository()
    
    private let context: NSManagedObjectContext
    @Published var weightEntries: [CDWeightEntry] = []
    @Published var currentWeight: Double?
    @Published var goalWeight: Double?
    @Published var latestEntry: CDWeightEntry?
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        fetchWeightEntries()
        loadGoalWeight()
    }
    
    // MARK: - Fetch Operations

    /// Re-reads the store into the published properties.
    ///
    /// Screens that show weight outside the Weight tab — the Dashboard and the
    /// Progress screen — call this on appear rather than fetching their own copy.
    /// One cache over one context is the point: a second instance would be a
    /// second `currentWeight`, and two of those can disagree.
    func refresh() {
        fetchWeightEntries()
        loadGoalWeight()
    }

    func fetchWeightEntries() {
        let request: NSFetchRequest<CDWeightEntry> = CDWeightEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDWeightEntry.date, ascending: false)]
        
        do {
            weightEntries = try context.fetch(request)
            latestEntry = weightEntries.first
            currentWeight = latestEntry?.weightKg
        } catch {
            print("Error fetching weight entries: \(error)")
        }
    }
    
    func fetchWeightEntries(for dateRange: DateRange) -> [CDWeightEntry] {
        let request: NSFetchRequest<CDWeightEntry> = CDWeightEntry.fetchRequest()
        
        let (startDate, endDate) = dateRange.dates
        request.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDWeightEntry.date, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching weight entries for date range: \(error)")
            return []
        }
    }
    
    // MARK: - Create Operations
    
    func createWeightEntry(
        weight: Double,
        date: Date = Date(),
        bodyFatPercentage: Double? = nil,
        muscleMass: Double? = nil,
        notes: String? = nil,
        source: String = "manual"
    ) -> CDWeightEntry {
        let entry = CDWeightEntry(context: context)
        entry.id = UUID()
        entry.weightKg = weight
        entry.date = date
        entry.source = source
        entry.syncStatus = "pending"
        
        // Safely set body composition data - these properties might not exist in Core Data
        do {
            entry.setValue(bodyFatPercentage ?? 0, forKey: "bodyFatPercentage")
            entry.setValue(muscleMass ?? 0, forKey: "muscleMass")
        } catch {
            // If properties don't exist in Core Data model, skip them
            print("Warning: bodyFatPercentage or muscleMass not available in Core Data model")
        }
        entry.notes = notes
        
        save()
        fetchWeightEntries()
        
        return entry
    }
    
    // Legacy method for compatibility
    func addWeightEntry(weightKg: Double, source: String = "manual") -> CDWeightEntry {
        return createWeightEntry(weight: weightKg, source: source)
    }
    
    // Convenience method for scale measurements
    func addEntry(
        weight: Double,
        unit: WeightUnit,
        source: String = "manual",
        notes: String? = nil
    ) async -> CDWeightEntry {
        // Convert to kg if needed
        let weightKg = unit == .lbs ? weight / 2.20462 : weight
        
        return await MainActor.run {
            createWeightEntry(
                weight: weightKg,
                date: Date(),
                notes: notes,
                source: source
            )
        }
    }
    
    // MARK: - Update Operations
    
    func updateWeightEntry(_ entry: CDWeightEntry, weight: Double? = nil, notes: String? = nil) {
        if let weight = weight {
            entry.weightKg = weight
        }
        
        if let notes = notes {
            entry.notes = notes
        }
        
        save()
        fetchWeightEntries()
    }
    
    // MARK: - Delete Operations
    
    func delete(_ entry: CDWeightEntry) {
        context.delete(entry)
        save()
        fetchWeightEntries()
    }
    
    func deleteWeightEntry(_ entry: CDWeightEntry) {
        delete(entry)
    }
    
    func deleteAllEntries() {
        let request: NSFetchRequest<NSFetchRequestResult> = CDWeightEntry.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            save()
            fetchWeightEntries()
        } catch {
            print("Error deleting all weight entries: \(error)")
        }
    }
    
    // MARK: - Goal Management
    
    func setGoalWeight(_ weight: Double) {
        UserDefaults.standard.set(weight, forKey: "goalWeight")
        goalWeight = weight
    }
    
    func setGoalDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "goalDate")
    }
    
    func getGoalDate() -> Date? {
        UserDefaults.standard.object(forKey: "goalDate") as? Date
    }
    
    private func loadGoalWeight() {
        let stored = UserDefaults.standard.double(forKey: "goalWeight")
        goalWeight = stored > 0 ? stored : nil
    }
    
    // MARK: - Statistics
    
    func calculateBMI(weight: Double, heightCm: Double) -> Double {
        let heightM = heightCm / 100.0
        return weight / (heightM * heightM)
    }
    
    func getBMICategory(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5:
            return "Underweight"
        case 18.5..<25:
            return "Normal"
        case 25..<30:
            return "Overweight"
        default:
            return "Obese"
        }
    }
    
    func getWeeklyAverage() -> Double? {
        let weekEntries = fetchWeightEntries(for: .week)
        guard !weekEntries.isEmpty else { return nil }
        
        let sum = weekEntries.reduce(0) { $0 + $1.weightKg }
        return sum / Double(weekEntries.count)
    }
    
    func getMonthlyAverage() -> Double? {
        let monthEntries = fetchWeightEntries(for: .month)
        guard !monthEntries.isEmpty else { return nil }
        
        let sum = monthEntries.reduce(0) { $0 + $1.weightKg }
        return sum / Double(monthEntries.count)
    }
    
    func getWeeklyChange() -> Double? {
        let weekEntries = fetchWeightEntries(for: .week)
        guard weekEntries.count >= 2 else { return nil }
        
        let oldest = weekEntries.first
        let newest = weekEntries.last
        
        guard let oldWeight = oldest?.weightKg,
              let newWeight = newest?.weightKg else { return nil }
        
        return newWeight - oldWeight
    }
    
    func getMonthlyChange() -> Double? {
        let monthEntries = fetchWeightEntries(for: .month)
        guard monthEntries.count >= 2 else { return nil }
        
        let oldest = monthEntries.first
        let newest = monthEntries.last
        
        guard let oldWeight = oldest?.weightKg,
              let newWeight = newest?.weightKg else { return nil }
        
        return newWeight - oldWeight
    }
    
    func getProgressToGoal() -> Double? {
        guard let current = currentWeight,
              let goal = goalWeight,
              let firstEntry = weightEntries.last else { return nil }
        
        let totalToLose = firstEntry.weightKg - goal
        let alreadyLost = firstEntry.weightKg - current
        
        guard totalToLose != 0 else { return 100 }
        
        return (alreadyLost / totalToLose) * 100
    }
    
    // MARK: - Analytics
    
    func getBestWeighInTime() -> String {
        // Analyze weight entry times to find most consistent time
        let hourCounts = weightEntries.reduce(into: [Int: Int]()) { counts, entry in
            guard let date = entry.date else { return }
            let hour = Calendar.current.component(.hour, from: date)
            counts[hour, default: 0] += 1
        }
        
        guard let mostFrequentHour = hourCounts.max(by: { $0.value < $1.value })?.key else {
            return "Morning"
        }
        
        switch mostFrequentHour {
        case 0..<6:
            return "Early Morning"
        case 6..<12:
            return "Morning"
        case 12..<18:
            return "Afternoon"
        default:
            return "Evening"
        }
    }
    
    func getWeightTrend() -> WeightTrend {
        let weekEntries = fetchWeightEntries(for: .week)
        guard weekEntries.count >= 3 else { return .stable }
        
        // Calculate linear regression
        let weights = weekEntries.map { $0.weightKg }
        let indices = Array(0..<weights.count).map { Double($0) }
        
        let meanX = indices.reduce(0, +) / Double(indices.count)
        let meanY = weights.reduce(0, +) / Double(weights.count)
        
        var numerator = 0.0
        var denominator = 0.0
        
        for i in 0..<weights.count {
            numerator += (indices[i] - meanX) * (weights[i] - meanY)
            denominator += pow(indices[i] - meanX, 2)
        }
        
        let slope = denominator != 0 ? numerator / denominator : 0
        
        // Determine trend based on slope
        if slope < -0.05 {
            return .losing
        } else if slope > 0.05 {
            return .gaining
        } else {
            return .stable
        }
    }
    
    // MARK: - Export
    
    func exportToCSV(dateRange: DateRange = .all, includeBodyComposition: Bool = true) -> URL? {
        let entries = fetchWeightEntries(for: dateRange)
        
        var headers = ["Date", "Weight (kg)", "Weight (lbs)", "BMI"]
        if includeBodyComposition {
            headers.append(contentsOf: ["Body Fat %", "Muscle Mass (kg)"])
        }
        headers.append(contentsOf: ["Source", "Notes"])
        
        var csvText = headers.joined(separator: ",") + "\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        let userHeight = UserDefaults.standard.double(forKey: "userHeightCm")
        
        for entry in entries.reversed() {
            var row: [String] = []
            
            // Date
            row.append(dateFormatter.string(from: entry.date ?? Date()))
            
            // Weight
            row.append(String(format: "%.1f", entry.weightKg))
            row.append(String(format: "%.1f", entry.weightKg * 2.20462))
            
            // BMI
            if let bmi = entry.bmi {
                row.append(String(format: "%.1f", bmi))
            } else {
                row.append("")
            }
            
            // Body Composition
            if includeBodyComposition {
                let bodyFat = (try? entry.value(forKey: "bodyFatPercentage") as? Double) ?? 0
                let muscleMass = (try? entry.value(forKey: "muscleMass") as? Double) ?? 0
                row.append(bodyFat > 0 ? String(format: "%.1f", bodyFat) : "")
                row.append(muscleMass > 0 ? String(format: "%.1f", muscleMass) : "")
            }
            
            // Source and Notes
            row.append(entry.source ?? "manual")
            row.append("\"\(entry.notes ?? "")\"")
            
            csvText += row.joined(separator: ",") + "\n"
        }
        
        let fileName = "weight_data_\(Date().timeIntervalSince1970).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("Error exporting CSV: \(error)")
            return nil
        }
    }
    
    func exportToJSON(dateRange: DateRange = .all, includeBodyComposition: Bool = true) -> URL? {
        let entries = fetchWeightEntries(for: dateRange)
        
        let dateFormatter = ISO8601DateFormatter()
        
        var jsonData: [[String: Any]] = []
        
        for entry in entries {
            var entryData: [String: Any] = [
                "date": dateFormatter.string(from: entry.date ?? Date()),
                "weightKg": entry.weightKg,
                "weightLbs": entry.weightKg * 2.20462,
                "source": entry.source ?? "manual"
            ]
            
            if let bmi = entry.bmi {
                entryData["bmi"] = bmi
            }
            
            if includeBodyComposition {
                let bodyFat = (try? entry.value(forKey: "bodyFatPercentage") as? Double) ?? 0
                let muscleMass = (try? entry.value(forKey: "muscleMass") as? Double) ?? 0
                
                if bodyFat > 0 {
                    entryData["bodyFatPercentage"] = bodyFat
                }
                if muscleMass > 0 {
                    entryData["muscleMassKg"] = muscleMass
                }
            }
            
            if let notes = entry.notes {
                entryData["notes"] = notes
            }
            
            jsonData.append(entryData)
        }
        
        let exportData: [String: Any] = [
            "exportDate": dateFormatter.string(from: Date()),
            "version": "1.0",
            "entriesCount": entries.count,
            "entries": jsonData
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            let fileName = "weight_data_\(Date().timeIntervalSince1970).json"
            let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: path)
            return path
        } catch {
            print("Error exporting JSON: \(error)")
            return nil
        }
    }
    
    func deleteAllData() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = CDWeightEntry.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            save()
            weightEntries.removeAll()
            currentWeight = nil
        } catch {
            print("Error deleting all weight data: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func save() {
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    // Additional missing methods
    func fetchAllWeightEntries() -> [CDWeightEntry] {
        fetchWeightEntries()
        return weightEntries
    }
    
    func setGoal(targetWeight: Double, targetDate: Date?) {
        setGoalWeight(targetWeight)
        if let date = targetDate {
            setGoalDate(date)
        }
    }
    
    func removeGoal() {
        UserDefaults.standard.removeObject(forKey: "goalWeight")
        UserDefaults.standard.removeObject(forKey: "goalDate")
        goalWeight = nil
    }
    
    func fetchLatestWeightEntry() -> CDWeightEntry? {
        return latestEntry
    }
    
    func getAverageWeight(for period: DateRange) -> Double? {
        let entries = fetchWeightEntries(for: period)
        guard !entries.isEmpty else { return nil }
        let totalWeight = entries.reduce(0) { $0 + $1.weightKg }
        return totalWeight / Double(entries.count)
    }
    
    func getAverageWeeklyChange() -> Double? {
        return getWeeklyChange()
    }
}

// MARK: - Supporting Types

enum DateRange {
    case week
    case month
    case threeMonths
    case sixMonths
    case year
    case all
    
    var dates: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return (start, now)
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            return (start, now)
        case .threeMonths:
            let start = calendar.date(byAdding: .month, value: -3, to: now)!
            return (start, now)
        case .sixMonths:
            let start = calendar.date(byAdding: .month, value: -6, to: now)!
            return (start, now)
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: now)!
            return (start, now)
        case .all:
            return (Date.distantPast, now)
        }
    }
    
    var displayName: String {
        switch self {
        case .week: return "1W"
        case .month: return "1M"
        case .threeMonths: return "3M"
        case .sixMonths: return "6M"
        case .year: return "1Y"
        case .all: return "all".localized
        }
    }
}

enum WeightTrend {
    case losing
    case gaining
    case stable
    
    var color: Color {
        switch self {
        case .losing: return .green
        case .gaining: return .red
        case .stable: return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .losing: return "arrow.down.circle.fill"
        case .gaining: return "arrow.up.circle.fill"
        case .stable: return "minus.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .losing: return "losing".localized
        case .gaining: return "gaining".localized
        case .stable: return "stable".localized
        }
    }
}