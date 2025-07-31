//
//  XiaomiScaleService.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreBluetooth
import Combine
import SwiftUI

extension Notification.Name {
    static let scaleWeightReceived = Notification.Name("scaleWeightReceived")
}

@MainActor
class XiaomiScaleService: ObservableObject {
    static let shared = XiaomiScaleService()
    
    // Published properties
    @Published private(set) var isConnected = false
    @Published private(set) var currentWeight: XiaomiScaleData?
    @Published private(set) var batteryInfo: ScaleBatteryInfo?
    @Published private(set) var lastMeasurement: Date?
    @Published private(set) var connectionStatus = "Disconnected"
    @Published private(set) var savedDeviceId: String?
    
    // Services
    private let bluetoothManager = BluetoothManager.shared
    
    // User profiles
    @Published var userProfiles: [ScaleUserProfile] = []
    @Published var currentProfile: ScaleUserProfile?
    
    // Internal state
    private var connectedPeripheral: CBPeripheral?
    private var weightCharacteristic: CBCharacteristic?
    private var batteryCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?
    private var cancellables = Set<AnyCancellable>()
    private var measurementTimer: Timer?
    private var readTimer: Timer?
    
    // Settings
    @AppStorage("autoConnectScale") private var autoConnect = true
    @AppStorage("scaleWeightUnit") private var preferredUnit = XiaomiScaleData.WeightUnit.kilograms.rawValue
    @AppStorage("savedScaleId") private var savedScaleId: String?
    
    private init() {
        // Delay weight repository initialization to break circular dependency
        setupObservers()
        loadUserProfiles()
        
        if let savedId = savedScaleId {
            savedDeviceId = savedId
        }
    }
    
    private func setupObservers() {
        // Observe Bluetooth state
        bluetoothManager.$bluetoothState
            .sink { [weak self] state in
                if state != .poweredOn {
                    self?.isConnected = false
                    self?.connectionStatus = "Bluetooth Off"
                }
            }
            .store(in: &cancellables)
        
        // Observe connection state
        bluetoothManager.$connectionState
            .sink { [weak self] state in
                self?.updateConnectionStatus(state)
            }
            .store(in: &cancellables)
        
        // Listen for characteristic updates
        NotificationCenter.default.publisher(for: .bluetoothCharacteristicUpdated)
            .sink { [weak self] notification in
                self?.handleCharacteristicUpdate(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Device Discovery
    
    func scanForScales() async -> [BluetoothDevice] {
        connectionStatus = "Scanning..."
        
        bluetoothManager.startScanning(for: nil) // Scan for all devices
        
        // Wait for scan to complete
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        
        bluetoothManager.stopScanning()
        
        // For debugging, show all devices first
        let allDevices = bluetoothManager.discoveredDevices
        print("XiaomiScaleService: Found \(allDevices.count) total devices")
        for device in allDevices {
            print("  - \(device.name) - Xiaomi: \(device.isXiaomiScale)")
        }
        
        // Return all devices for now to help identify the scale
        connectionStatus = allDevices.isEmpty ? "No devices found" : "Found \(allDevices.count) device(s)"
        
        return allDevices // Return all devices for debugging
    }
    
    // MARK: - Connection Management
    
    func connect(to device: BluetoothDevice) async -> Bool {
        // Prevent multiple connection attempts
        guard !isConnected && connectionStatus != "Connecting..." else {
            print("XiaomiScaleService: Already connected or connecting")
            return false
        }
        
        print("XiaomiScaleService: Connecting to device: \(device.name)")
        connectionStatus = "Connecting..."
        
        let success = await bluetoothManager.connect(to: device)
        print("XiaomiScaleService: Connection result: \(success)")
        
        if success {
            connectedPeripheral = device.peripheral
            savedScaleId = device.peripheral.identifier.uuidString
            savedDeviceId = device.peripheral.identifier.uuidString
            print("XiaomiScaleService: Setting up scale services...")
            await setupScale(device.peripheral)
            return true
        } else {
            connectionStatus = "Connection failed"
            return false
        }
    }
    
    func disconnect() {
        stopMeasurementTimer()
        stopReadTimer()
        bluetoothManager.disconnect()
        connectedPeripheral = nil
        weightCharacteristic = nil
        batteryCharacteristic = nil
        writeCharacteristic = nil
        isConnected = false
    }
    
    func connectToSavedDevice() async {
        guard let savedId = savedScaleId,
              let uuid = UUID(uuidString: savedId) else { return }
        
        connectionStatus = "Reconnecting..."
        
        // Try to find the device
        let scales = await scanForScales()
        
        if let device = scales.first(where: { $0.peripheral.identifier == uuid }) {
            _ = await connect(to: device)
        } else {
            connectionStatus = "Saved scale not found"
        }
    }
    
    // MARK: - Scale Setup
    
    private func setupScale(_ peripheral: CBPeripheral) async {
        print("XiaomiScaleService: Discovering services...")
        
        // Discover ALL services first to see what's available
        let services = await bluetoothManager.discoverServices(
            for: peripheral,
            serviceUUIDs: nil // Discover all services
        )
        
        print("XiaomiScaleService: Found \(services.count) services:")
        for service in services {
            print("  - Service UUID: \(service.uuid.uuidString)")
        }
        
        // Try to find weight-related services
        var foundWeightService = false
        
        // Check standard weight service
        if let weightService = services.first(where: { $0.uuid == XiaomiScaleUUIDs.weightService }) {
            print("XiaomiScaleService: Found standard weight service")
            await setupWeightCharacteristics(for: weightService, peripheral: peripheral)
            foundWeightService = true
        }
        
        // Check S400 specific service
        if let s400Service = services.first(where: { $0.uuid == XiaomiScaleUUIDs.s400Service }) {
            print("XiaomiScaleService: Found S400 service, setting up S400 characteristics")
            await setupS400Characteristics(for: s400Service, peripheral: peripheral)
            foundWeightService = true
        }
        
        // Check Xiaomi custom services
        for customUUID in [XiaomiScaleUUIDs.customService, XiaomiScaleUUIDs.miScaleService, XiaomiScaleUUIDs.miScaleV2Service, XiaomiScaleUUIDs.miService] {
            if let customService = services.first(where: { $0.uuid == customUUID }) {
                print("XiaomiScaleService: Found custom service: \(customUUID.uuidString)")
                await setupCustomCharacteristics(for: customService, peripheral: peripheral)
                foundWeightService = true
            }
        }
        
        if !foundWeightService {
            print("XiaomiScaleService: No weight service found, trying all services")
            // Try to enable notifications on all characteristics
            for service in services {
                await setupAllCharacteristics(for: service, peripheral: peripheral)
            }
        }
        
        // Setup battery monitoring
        if let batteryService = services.first(where: { $0.uuid == XiaomiScaleUUIDs.batteryService }) {
            print("XiaomiScaleService: Found battery service")
            let characteristics = await bluetoothManager.discoverCharacteristics(
                for: batteryService,
                characteristicUUIDs: [XiaomiScaleUUIDs.batteryLevel]
            )
            
            if let batteryChar = characteristics.first(where: { $0.uuid == XiaomiScaleUUIDs.batteryLevel }) {
                batteryCharacteristic = batteryChar
                peripheral.readValue(for: batteryChar)
                peripheral.setNotifyValue(true, for: batteryChar)
            }
        }
        
        isConnected = true
        connectionStatus = "Connected"
        print("XiaomiScaleService: Setup complete, isConnected: \(isConnected)")
        
        // For S400, just wait for passive broadcasts
        if connectedPeripheral?.name?.lowercased().contains("s400") == true {
            print("XiaomiScaleService: S400 detected")
            print("XiaomiScaleService: IMPORTANT - S400 Instructions:")
            print("  1. Make sure the scale is NOT connected to Mi Home app")
            print("  2. Step on the scale and wait for it to stabilize")
            print("  3. The scale should broadcast data automatically")
            print("XiaomiScaleService: Notifications enabled on all characteristics")
            print("XiaomiScaleService: Waiting for weight data...")
            
            // For S400, also check if we can read from any characteristics
            Task {
                await checkS400Characteristics()
            }
        } else if writeCharacteristic != nil {
            // Other scales might need triggers
            startMeasurementTimer()
        }
    }
    
    private func setupS400Characteristics(for service: CBService, peripheral: CBPeripheral) async {
        let characteristics = await bluetoothManager.discoverCharacteristics(
            for: service,
            characteristicUUIDs: nil
        )
        
        print("XiaomiScaleService: Found \(characteristics.count) characteristics in S400 service")
        
        // Look for the specific S400 weight characteristic
        if let weightChar = characteristics.first(where: { $0.uuid == XiaomiScaleUUIDs.s400WeightCharacteristic }) {
            print("XiaomiScaleService: Found S400 weight characteristic, enabling notifications")
            peripheral.setNotifyValue(true, for: weightChar)
            weightCharacteristic = weightChar
            
            // Also try reading the value directly
            peripheral.readValue(for: weightChar)
            
            // For S400, try to initiate measurement after setup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                // Try reading from the weight characteristic first
                peripheral.readValue(for: weightChar)
                print("XiaomiScaleService: Initiated read from S400 weight characteristic")
            }
        }
        
        // Enable notifications on all other characteristics too
        for char in characteristics {
            print("  - S400 Characteristic: \(char.uuid.uuidString), Properties: \(describeProperties(char.properties))")
            
            // Use the S400's writeWithoutResponse characteristic (00008001) instead
            if char.uuid.uuidString.uppercased() == "00008001-0065-6C62-2E74-6F696D2E696D" && 
               char.properties.contains(.writeWithoutResponse) {
                print("    Found S400 writable characteristic 00008001 for measurement trigger")
                writeCharacteristic = char
            }
            
            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                print("    Enabling notifications/indications")
                peripheral.setNotifyValue(true, for: char)
            }
            if char.properties.contains(.read) {
                print("    Reading value")
                peripheral.readValue(for: char)
            }
        }
    }
    
    private func setupWeightCharacteristics(for service: CBService, peripheral: CBPeripheral) async {
        let characteristics = await bluetoothManager.discoverCharacteristics(
            for: service,
            characteristicUUIDs: nil // Discover all
        )
        
        print("XiaomiScaleService: Found \(characteristics.count) characteristics in weight service")
        for char in characteristics {
            print("  - Characteristic: \(char.uuid.uuidString)")
            if char.properties.contains(.notify) {
                print("    Enabling notifications")
                peripheral.setNotifyValue(true, for: char)
                weightCharacteristic = char
            }
        }
    }
    
    private func setupCustomCharacteristics(for service: CBService, peripheral: CBPeripheral) async {
        let characteristics = await bluetoothManager.discoverCharacteristics(
            for: service,
            characteristicUUIDs: nil
        )
        
        print("XiaomiScaleService: Found \(characteristics.count) characteristics in custom service")
        for char in characteristics {
            print("  - Characteristic: \(char.uuid.uuidString), Properties: \(describeProperties(char.properties))")
            
            // Look for writable characteristics in FE95 service (prefer 0010)
            if char.uuid.uuidString.uppercased() == "0010" && char.properties.contains(.writeWithoutResponse) {
                print("    Found FE95 writable characteristic 0010 for measurement trigger")
                writeCharacteristic = char
            }
            
            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                print("    Enabling notifications/indications")
                peripheral.setNotifyValue(true, for: char)
                if weightCharacteristic == nil {
                    weightCharacteristic = char
                }
            }
        }
    }
    
    private func setupAllCharacteristics(for service: CBService, peripheral: CBPeripheral) async {
        let characteristics = await bluetoothManager.discoverCharacteristics(
            for: service,
            characteristicUUIDs: nil
        )
        
        for char in characteristics {
            print("XiaomiScaleService: Characteristic \(char.uuid.uuidString) - Properties: \(describeProperties(char.properties))")
            
            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                print("XiaomiScaleService: Enabling notifications on \(char.uuid.uuidString)")
                peripheral.setNotifyValue(true, for: char)
            }
            
            // Save writable characteristic (0017) for triggering measurements
            if char.uuid.uuidString.uppercased() == "0017" && char.properties.contains(.write) {
                print("XiaomiScaleService: Found writable characteristic 0017")
                writeCharacteristic = char
            }
        }
    }
    
    private func describeProperties(_ properties: CBCharacteristicProperties) -> String {
        var props: [String] = []
        if properties.contains(.read) { props.append("read") }
        if properties.contains(.write) { props.append("write") }
        if properties.contains(.writeWithoutResponse) { props.append("writeWithoutResponse") }
        if properties.contains(.notify) { props.append("notify") }
        if properties.contains(.indicate) { props.append("indicate") }
        return props.joined(separator: ", ")
    }
    
    // MARK: - Data Handling
    
    private func handleCharacteristicUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let characteristic = userInfo["characteristic"] as? CBCharacteristic,
              let data = userInfo["value"] as? Data else { return }
        
        print("XiaomiScaleService: Handling characteristic update - UUID: \(characteristic.uuid.uuidString)")
        print("XiaomiScaleService: Raw data received: \(data.hexEncodedString()) (length: \(data.count))")
        
        // Log data as different interpretations
        if data.count >= 2 {
            let uint16Value = data.withUnsafeBytes { $0.load(as: UInt16.self) }
            let uint16BigEndian = data.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            print("XiaomiScaleService: Data as UInt16 (LE): \(uint16Value), as UInt16 (BE): \(uint16BigEndian)")
            print("XiaomiScaleService: Possible weight (LE): \(Double(uint16Value) * 0.01) kg")
            print("XiaomiScaleService: Possible weight (BE): \(Double(uint16BigEndian) * 0.01) kg")
        }
        
        // S400 specific - check if this is from the notification characteristic
        if characteristic.uuid.uuidString.uppercased() == "00008002-0065-6C62-2E74-6F696D2E696D" {
            print("XiaomiScaleService: S400 weight notification received")
            handleS400WeightData(data)
        }
        // Check FE95 service characteristics
        else if characteristic.service?.uuid.uuidString == "FE95" {
            print("XiaomiScaleService: FE95 service data from characteristic: \(characteristic.uuid.uuidString)")
            
            // Different FE95 characteristics might contain different data
            switch characteristic.uuid.uuidString.uppercased() {
            case "0005":
                print("  - Possible device info/status")
                handleFE95DeviceInfo(data)
            case "0010", "0019", "0018", "001A", "001B", "001C":
                print("  - Possible measurement data")
                handleFE95MeasurementData(data)
            default:
                print("  - Unknown FE95 characteristic")
            }
        }
        // Try standard weight measurement
        else if characteristic.uuid == XiaomiScaleUUIDs.weightMeasurement {
            handleWeightData(data)
        } 
        // Try battery level
        else if characteristic.uuid == XiaomiScaleUUIDs.batteryLevel {
            handleBatteryData(data)
        } 
        // Try as potential weight data from any characteristic
        else if data.count >= 2 {
            print("XiaomiScaleService: Trying to parse as weight data from characteristic: \(characteristic.uuid.uuidString)")
            handleWeightData(data)
        }
    }
    
    private func handleWeightData(_ data: Data) {
        print("XiaomiScaleService: Received weight data: \(data.hexEncodedString())")
        
        guard let scaleData = XiaomiScaleData.parse(from: data) else {
            print("XiaomiScaleService: Failed to parse weight data")
            return
        }
        
        print("XiaomiScaleService: Parsed weight: \(scaleData.weight) \(scaleData.unit.rawValue), stabilized: \(scaleData.isStabilized)")
        
        currentWeight = scaleData
        
        // Only save stabilized measurements
        if scaleData.isStabilized {
            lastMeasurement = Date()
            
            // Identify user based on weight
            if let profile = identifyUser(weight: scaleData.weight) {
                currentProfile = profile
                print("XiaomiScaleService: Identified user: \(profile.name)")
                saveWeightMeasurement(scaleData, profile: profile)
            } else {
                // Ask user to confirm or create profile
                print("XiaomiScaleService: No matching user profile found")
                saveWeightMeasurement(scaleData, profile: nil)
            }
        }
    }
    
    private func handleBatteryData(_ data: Data) {
        guard let level = XiaomiScaleData.parseBatteryLevel(from: data) else { return }
        
        batteryInfo = ScaleBatteryInfo(
            level: level,
            isLow: level < 20,
            lastUpdated: Date()
        )
    }
    
    // MARK: - S400 Specific Data Handlers
    
    private func handleS400WeightData(_ data: Data) {
        print("XiaomiScaleService: Parsing S400 weight data: \(data.hexEncodedString())")
        
        // S400 might use a different format
        // Try various interpretations
        if data.count >= 2 {
            let bytes = [UInt8](data)
            
            // Try different byte orders and scales
            let weight1 = Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) * 0.01  // Big endian, 0.01 scale
            let weight2 = Double(UInt16(bytes[1]) << 8 | UInt16(bytes[0])) * 0.01  // Little endian, 0.01 scale
            let weight3 = Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) * 0.1   // Big endian, 0.1 scale
            let weight4 = Double(UInt16(bytes[1]) << 8 | UInt16(bytes[0])) * 0.1   // Little endian, 0.1 scale
            
            print("  Possible weights: \(weight1)kg, \(weight2)kg, \(weight3)kg, \(weight4)kg")
            
            // Check if any weight is reasonable
            for weight in [weight1, weight2, weight3, weight4] {
                if weight > 20 && weight < 200 {
                    let scaleData = XiaomiScaleData(
                        weight: weight,
                        timestamp: Date(),
                        isStabilized: true,
                        unit: .kilograms,
                        impedance: nil,
                        userProfile: nil
                    )
                    currentWeight = scaleData
                    lastMeasurement = Date()
                    saveWeightMeasurement(scaleData, profile: nil)
                    return
                }
            }
        }
    }
    
    private func handleFE95DeviceInfo(_ data: Data) {
        print("XiaomiScaleService: FE95 device info: \(data.hexEncodedString())")
        // Parse device information if needed
    }
    
    private func handleFE95MeasurementData(_ data: Data) {
        print("XiaomiScaleService: FE95 measurement data: \(data.hexEncodedString())")
        
        // FE95 service might encode weight differently
        if data.count >= 11 {
            // Try the standard Mi Scale format (bytes 11-12 for weight)
            let bytes = [UInt8](data)
            if data.count > 12 {
                let weightRaw = UInt16(bytes[11]) | (UInt16(bytes[12]) << 8)
                let weight = Double(weightRaw) / 200.0  // Standard Mi Scale division
                
                print("  Parsed weight (Mi Scale format): \(weight) kg")
                
                if weight > 20 && weight < 200 {
                    let scaleData = XiaomiScaleData(
                        weight: weight,
                        timestamp: Date(),
                        isStabilized: true,
                        unit: .kilograms,
                        impedance: nil,
                        userProfile: nil
                    )
                    currentWeight = scaleData
                    lastMeasurement = Date()
                    saveWeightMeasurement(scaleData, profile: nil)
                    return
                }
            }
        }
        
        // Try S400 specific format
        handleS400WeightData(data)
    }
    
    // MARK: - User Management
    
    private func identifyUser(weight: Double) -> ScaleUserProfile? {
        // Find profile that matches weight
        return userProfiles.first { $0.matches(weight: weight) }
    }
    
    private func loadUserProfiles() {
        // Load from UserDefaults or create default
        if let data = UserDefaults.standard.data(forKey: "scaleUserProfiles"),
           let profiles = try? JSONDecoder().decode([ScaleUserProfile].self, from: data) {
            userProfiles = profiles
        } else {
            // Create default profile based on current user
            userProfiles = [
                ScaleUserProfile(
                    id: 1,
                    weightRange: 50...100,
                    lastWeight: nil,
                    name: "Me"
                )
            ]
        }
    }
    
    func saveUserProfiles() {
        if let data = try? JSONEncoder().encode(userProfiles) {
            UserDefaults.standard.set(data, forKey: "scaleUserProfiles")
        }
    }
    
    // MARK: - Weight Saving
    
    private func saveWeightMeasurement(_ data: XiaomiScaleData, profile: ScaleUserProfile?) {
        Task {
            // Always save weight in kg to the database
            let weightInKg = data.unit == .pounds ? data.weight / 2.20462 : data.weight
            
            // Post notification for weight to be saved by the view that has access to repository
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .scaleWeightReceived,
                    object: nil,
                    userInfo: [
                        "weight": weightInKg,
                        "unit": "kg",
                        "source": "Xiaomi Scale",
                        "notes": profile?.name ?? ""
                    ]
                )
            }
            
            // Update profile's last weight
            if var profile = profile,
               let index = userProfiles.firstIndex(where: { $0.id == profile.id }) {
                profile = ScaleUserProfile(
                    id: profile.id,
                    weightRange: profile.weightRange,
                    lastWeight: data.weight,
                    name: profile.name
                )
                userProfiles[index] = profile
                saveUserProfiles()
            }
        }
    }
    
    // MARK: - Status Updates
    
    private func updateConnectionStatus(_ state: BluetoothManager.ConnectionState) {
        switch state {
        case .disconnected:
            connectionStatus = "Disconnected"
            isConnected = false
            stopMeasurementTimer()
            stopReadTimer()
            connectedPeripheral = nil
            writeCharacteristic = nil
        case .connecting:
            connectionStatus = "Connecting..."
        case .connected:
            connectionStatus = "Connected"
            isConnected = true
        case .disconnecting:
            connectionStatus = "Disconnecting..."
        }
    }
    
    // MARK: - Measurement Trigger
    
    private func startMeasurementTimer() {
        print("XiaomiScaleService: Starting measurement timer")
        
        // Stop any existing timer
        stopMeasurementTimer()
        
        // Send initial trigger
        triggerMeasurement()
        
        // Set up periodic trigger every 3 seconds (less aggressive)
        measurementTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.triggerMeasurement()
        }
    }
    
    private func stopMeasurementTimer() {
        measurementTimer?.invalidate()
        measurementTimer = nil
    }
    
    // MARK: - S400 Specific Methods
    
    private func checkS400Characteristics() async {
        guard let peripheral = connectedPeripheral else { return }
        
        print("XiaomiScaleService: Checking S400 characteristics for readable data...")
        
        // Check all services and characteristics
        for service in peripheral.services ?? [] {
            for characteristic in service.characteristics ?? [] {
                print("XiaomiScaleService: Checking \(characteristic.uuid.uuidString)")
                
                // Try to read if possible
                if characteristic.properties.contains(.read) {
                    print("  - Reading from \(characteristic.uuid.uuidString)")
                    peripheral.readValue(for: characteristic)
                }
                
                // Check notification state
                print("  - Notifying: \(characteristic.isNotifying)")
                
                // For FE95 service, try specific reads
                if service.uuid.uuidString == "FE95" {
                    if characteristic.uuid.uuidString == "0004" || characteristic.uuid.uuidString == "0005" {
                        print("  - Reading FE95 characteristic \(characteristic.uuid.uuidString)")
                        peripheral.readValue(for: characteristic)
                    }
                }
            }
        }
    }
    
    // MARK: - Read Timer for S400
    
    private func startReadTimer() {
        print("XiaomiScaleService: Starting read timer for S400")
        
        // Stop any existing timer
        stopReadTimer()
        
        // Read immediately
        readWeightCharacteristic()
        
        // Set up periodic reads every 2 seconds
        readTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.readWeightCharacteristic()
        }
    }
    
    private func stopReadTimer() {
        readTimer?.invalidate()
        readTimer = nil
    }
    
    private func readWeightCharacteristic() {
        guard let weightChar = weightCharacteristic,
              let peripheral = connectedPeripheral,
              isConnected else {
            return
        }
        
        // Try reading the weight characteristic
        if weightChar.properties.contains(.read) {
            print("XiaomiScaleService: Reading weight characteristic")
            peripheral.readValue(for: weightChar)
        }
        
        // Also check if we need to re-enable notifications
        if weightChar.properties.contains(.notify) && !weightChar.isNotifying {
            print("XiaomiScaleService: Re-enabling notifications")
            peripheral.setNotifyValue(true, for: weightChar)
        }
    }
    
    private func triggerMeasurement() {
        guard let writeChar = writeCharacteristic,
              let peripheral = connectedPeripheral,
              isConnected else {
            print("XiaomiScaleService: Not connected or no write characteristic available")
            return
        }
        
        print("XiaomiScaleService: Triggering measurement")
        
        // S400/Mi Scale protocol commands for characteristic 0010
        let triggerCommands: [Data] = [
            // Mi Band/Scale protocol for 0010
            Data([0x01, 0x01]),                  // Enable notifications
            Data([0x02, 0x01]),                  // Start measurement
            Data([0x01, 0x03]),                  // Request data
            Data([0x06, 0x01]),                  // Get weight
            
            // Alternative formats
            Data([0x01]),                        // Simple enable
            Data([0x02]),                        // Simple start
            Data([0xFF]),                        // Reset/trigger
            
            // Xiaomi specific
            Data([0x01, 0x00, 0x00]),           // Three byte format
            Data([0x02, 0x00, 0x00]),           // Alternative three byte
            Data([0x10, 0x01, 0x01])            // Another variant
        ]
        
        // Try commands sequentially
        let commandIndex = Int(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: Double(triggerCommands.count)))
        let command = triggerCommands[commandIndex]
        
        print("XiaomiScaleService: Writing command: \(command.hexEncodedString()) to characteristic \(writeChar.uuid.uuidString)")
        
        // Use writeWithoutResponse for S400 to avoid encryption issues
        peripheral.writeValue(command, for: writeChar, type: .withoutResponse)
    }
}

// MARK: - Codable Extensions
