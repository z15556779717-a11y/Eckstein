//
//  XiaomiScaleData.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation

struct XiaomiScaleData {
    let weight: Double // in kg
    let timestamp: Date
    let isStabilized: Bool
    let unit: WeightUnit
    let impedance: Int? // For body composition scales
    let userProfile: ScaleUserProfile?
    
    enum WeightUnit: String {
        case kilograms = "kg"
        case pounds = "lbs"
        case jin = "jin" // Chinese unit
        
        func convert(_ weight: Double, to targetUnit: WeightUnit) -> Double {
            guard self != targetUnit else { return weight }
            
            // First convert to kg
            let weightInKg: Double
            switch self {
            case .kilograms:
                weightInKg = weight
            case .pounds:
                weightInKg = weight * 0.453592
            case .jin:
                weightInKg = weight * 0.5
            }
            
            // Then convert to target unit
            switch targetUnit {
            case .kilograms:
                return weightInKg
            case .pounds:
                return weightInKg * 2.20462
            case .jin:
                return weightInKg * 2
            }
        }
    }
}

struct ScaleUserProfile: Codable {
    let id: Int
    let weightRange: ClosedRange<Double>
    let lastWeight: Double?
    let name: String
    
    func matches(weight: Double) -> Bool {
        return weightRange.contains(weight)
    }
}

struct ScaleBatteryInfo {
    let level: Int // 0-100
    let isLow: Bool
    let lastUpdated: Date
    
    var description: String {
        switch level {
        case 80...100:
            return "Battery Good (\(level)%)"
        case 50..<80:
            return "Battery OK (\(level)%)"
        case 20..<50:
            return "Battery Low (\(level)%)"
        default:
            return "Battery Critical (\(level)%)"
        }
    }
}

// MARK: - Data Parsing

extension XiaomiScaleData {
    static func parse(from data: Data) -> XiaomiScaleData? {
        // Try multiple parsing formats
        if let result = parseStandardFormat(from: data) {
            return result
        }
        if let result = parseAlternativeFormat(from: data) {
            return result
        }
        if let result = parseSimpleFormat(from: data) {
            return result
        }
        return nil
    }
    
    // Standard Xiaomi format
    private static func parseStandardFormat(from data: Data) -> XiaomiScaleData? {
        guard data.count >= 10 else { return nil }
        
        let bytes = [UInt8](data)
        
        // Parse control bytes
        let controlByte1 = bytes[0]
        let controlByte2 = bytes[1]
        
        // Check if weight is stabilized
        let isStabilized = (controlByte1 & 0x20) != 0
        
        // Parse weight unit
        let unitBits = controlByte1 & 0x03
        let unit: WeightUnit
        switch unitBits {
        case 0x00:
            unit = .kilograms
        case 0x01:
            unit = .pounds
        case 0x02:
            unit = .jin
        default:
            unit = .kilograms
        }
        
        // Parse weight value (bytes 2-3)
        let weightRaw = UInt16(bytes[3]) << 8 | UInt16(bytes[2])
        let weight: Double
        
        switch unit {
        case .kilograms, .jin:
            weight = Double(weightRaw) * 0.01 // Weight in 0.01 kg units
        case .pounds:
            weight = Double(weightRaw) * 0.01 // Weight in 0.01 lbs units
        }
        
        // Parse impedance if available (bytes 4-5)
        var impedance: Int? = nil
        if data.count >= 6 && (controlByte2 & 0x02) != 0 {
            impedance = Int(UInt16(bytes[5]) << 8 | UInt16(bytes[4]))
        }
        
        return XiaomiScaleData(
            weight: weight,
            timestamp: Date(),
            isStabilized: isStabilized,
            unit: unit,
            impedance: impedance,
            userProfile: nil
        )
    }
    
    // Alternative format (some scales use different byte order)
    private static func parseAlternativeFormat(from data: Data) -> XiaomiScaleData? {
        guard data.count >= 3 else { return nil }
        
        let bytes = [UInt8](data)
        
        // Try parsing as simple weight in kg (2 bytes, little endian)
        let weightRaw = UInt16(bytes[1]) << 8 | UInt16(bytes[0])
        let weight = Double(weightRaw) * 0.01
        
        // Validate reasonable weight range
        guard weight > 10 && weight < 300 else { return nil }
        
        return XiaomiScaleData(
            weight: weight,
            timestamp: Date(),
            isStabilized: true,
            unit: .kilograms,
            impedance: nil,
            userProfile: nil
        )
    }
    
    // Simple format (just weight data)
    private static func parseSimpleFormat(from data: Data) -> XiaomiScaleData? {
        guard data.count >= 2 else { return nil }
        
        let bytes = [UInt8](data)
        
        // Try different interpretations
        let weight1 = Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) * 0.01
        let weight2 = Double(UInt16(bytes[1]) << 8 | UInt16(bytes[0])) * 0.01
        let weight3 = Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) * 0.1
        let weight4 = Double(UInt16(bytes[1]) << 8 | UInt16(bytes[0])) * 0.1
        
        // Pick the most reasonable weight
        for weight in [weight1, weight2, weight3, weight4] {
            if weight > 10 && weight < 300 {
                return XiaomiScaleData(
                    weight: weight,
                    timestamp: Date(),
                    isStabilized: true,
                    unit: .kilograms,
                    impedance: nil,
                    userProfile: nil
                )
            }
        }
        
        return nil
    }
    
    static func parseBatteryLevel(from data: Data) -> Int? {
        guard data.count >= 1 else { return nil }
        return Int(data[0])
    }
}