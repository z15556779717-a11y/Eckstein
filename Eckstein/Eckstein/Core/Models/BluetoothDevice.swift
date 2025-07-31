//
//  BluetoothDevice.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreBluetooth

struct BluetoothDevice: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    let rssi: Int
    let advertisementData: [String: Any]
    let isXiaomiScale: Bool
    let batteryLevel: Int?
    
    init(
        peripheral: CBPeripheral,
        rssi: NSNumber,
        advertisementData: [String: Any]
    ) {
        self.id = UUID()
        self.peripheral = peripheral
        self.name = peripheral.name ?? "Unknown Device"
        self.rssi = rssi.intValue
        self.advertisementData = advertisementData
        self.isXiaomiScale = BluetoothDevice.isXiaomiDevice(
            name: peripheral.name,
            advertisementData: advertisementData
        )
        self.batteryLevel = nil
    }
    
    var signalStrength: SignalStrength {
        switch rssi {
        case -50...0:
            return .excellent
        case -60..<(-50):
            return .good
        case -70..<(-60):
            return .fair
        default:
            return .poor
        }
    }
    
    enum SignalStrength {
        case excellent
        case good
        case fair
        case poor
        
        var color: String {
            switch self {
            case .excellent:
                return "green"
            case .good:
                return "blue"
            case .fair:
                return "orange"
            case .poor:
                return "red"
            }
        }
        
        var description: String {
            switch self {
            case .excellent:
                return "Excellent"
            case .good:
                return "Good"
            case .fair:
                return "Fair"
            case .poor:
                return "Poor"
            }
        }
    }
    
    static func isXiaomiDevice(name: String?, advertisementData: [String: Any]) -> Bool {
        // First check service UUIDs - more reliable than name
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            for uuid in serviceUUIDs {
                if XiaomiScaleUUIDs.allServiceUUIDs.contains(uuid) {
                    print("BluetoothDevice: Found Xiaomi device by service UUID: \(uuid.uuidString)")
                    return true
                }
            }
        }
        
        // Then check by name
        guard let name = name?.lowercased() else { return false }
        
        // Check for known Xiaomi scale names
        let knownNames = [
            "mi scale",
            "mi body",
            "mi smart",
            "xiaomi",
            "miscale",
            "yunmai" // Some Xiaomi scales show up as Yunmai
        ]
        
        for knownName in knownNames {
            if name.contains(knownName) {
                print("BluetoothDevice: Found Xiaomi device by name: \(name)")
                return true
            }
        }
        
        // Log device info for debugging
        print("BluetoothDevice: Not Xiaomi - Name: \(name), Services: \(advertisementData[CBAdvertisementDataServiceUUIDsKey] ?? "none")")
        
        return false
    }
}

// MARK: - Xiaomi Scale UUIDs

struct XiaomiScaleUUIDs {
    // Service UUIDs
    static let weightService = CBUUID(string: "181D") // Weight Scale Service
    static let bodyCompositionService = CBUUID(string: "181B") // Body Composition Service
    static let deviceInfoService = CBUUID(string: "180A") // Device Information Service
    static let batteryService = CBUUID(string: "180F") // Battery Service
    
    // Characteristic UUIDs
    static let weightMeasurement = CBUUID(string: "2A9D") // Weight Measurement
    static let bodyCompositionMeasurement = CBUUID(string: "2A9C") // Body Composition Measurement
    static let batteryLevel = CBUUID(string: "2A19") // Battery Level
    
    // Custom Xiaomi UUIDs (found in various Xiaomi scales)
    static let customService = CBUUID(string: "00001530-0000-3512-2118-0009AF100700")
    static let customCharacteristic = CBUUID(string: "00001531-0000-3512-2118-0009AF100700")
    
    // Additional Xiaomi scale service UUIDs
    static let miScaleService = CBUUID(string: "0000FFF0-0000-1000-8000-00805F9B34FB")
    static let miScaleV2Service = CBUUID(string: "0000FFB0-0000-1000-8000-00805F9B34FB")
    
    // Xiaomi S400 specific UUIDs
    static let s400Service = CBUUID(string: "00008000-0065-6C62-2E74-6F696D2E696D")
    static let s400WeightCharacteristic = CBUUID(string: "00008002-0065-6C62-2E74-6F696D2E696D")
    static let miService = CBUUID(string: "FE95")
    
    static let allServiceUUIDs: [CBUUID] = [
        weightService,
        bodyCompositionService,
        deviceInfoService,
        batteryService,
        customService,
        miScaleService,
        miScaleV2Service,
        s400Service,
        miService
    ]
}