//
//  BluetoothManager.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreBluetooth
import Combine

@MainActor
class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()
    
    // Published properties
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var isScanning = false
    @Published private(set) var discoveredDevices: [BluetoothDevice] = []
    @Published private(set) var connectedDevice: BluetoothDevice?
    @Published private(set) var connectionState: ConnectionState = .disconnected
    
    // Core Bluetooth
    private var centralManager: CBCentralManager!
    private var scanTimer: Timer?
    private let scanDuration: TimeInterval = 10.0
    
    // Connection management
    private var connectionContinuation: CheckedContinuation<Bool, Never>?
    private var characteristicsContinuation: CheckedContinuation<[CBCharacteristic], Never>?
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case disconnecting
        
        var description: String {
            switch self {
            case .disconnected:
                return "Disconnected"
            case .connecting:
                return "Connecting..."
            case .connected:
                return "Connected"
            case .disconnecting:
                return "Disconnecting..."
            }
        }
    }
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Scanning
    
    func startScanning(for services: [CBUUID]? = nil) {
        guard bluetoothState == .poweredOn else {
            print("BluetoothManager: Bluetooth not powered on, state: \(bluetoothState)")
            return
        }
        
        guard !isScanning else { return }
        
        print("BluetoothManager: Starting scan for services: \(services?.map { $0.uuidString } ?? ["All"])")
        
        discoveredDevices.removeAll()
        isScanning = true
        
        // Scan without service filter first to see all devices
        centralManager.scanForPeripherals(
            withServices: nil, // Changed to nil to see all devices
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // Auto-stop after duration
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: scanDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopScanning()
            }
        }
    }
    
    func stopScanning() {
        guard isScanning else { return }
        
        centralManager.stopScan()
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil
    }
    
    // MARK: - Connection
    
    func connect(to device: BluetoothDevice) async -> Bool {
        guard connectionState == .disconnected else { return false }
        
        connectionState = .connecting
        
        return await withCheckedContinuation { continuation in
            self.connectionContinuation = continuation
            
            // Enable encryption/bonding for Xiaomi scales
            let options: [String: Any] = [
                CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
            ]
            
            centralManager.connect(device.peripheral, options: options)
            
            // Timeout after 15 seconds (increased for bonding)
            Task {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if self.connectionState == .connecting {
                    self.cancelConnection()
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    func disconnect() {
        guard let device = connectedDevice else { return }
        
        connectionState = .disconnecting
        centralManager.cancelPeripheralConnection(device.peripheral)
    }
    
    private func cancelConnection() {
        connectionState = .disconnected
        if let continuation = connectionContinuation {
            continuation.resume(returning: false)
            connectionContinuation = nil
        }
    }
    
    // MARK: - Service Discovery
    
    func discoverServices(for peripheral: CBPeripheral, serviceUUIDs: [CBUUID]?) async -> [CBService] {
        peripheral.delegate = self
        peripheral.discoverServices(serviceUUIDs)
        
        return await withCheckedContinuation { continuation in
            // Store continuation to be resumed when services are discovered
            // This is simplified - in production you'd want proper continuation management
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                continuation.resume(returning: peripheral.services ?? [])
            }
        }
    }
    
    func discoverCharacteristics(for service: CBService, characteristicUUIDs: [CBUUID]?) async -> [CBCharacteristic] {
        service.peripheral?.discoverCharacteristics(characteristicUUIDs, for: service)
        
        return await withCheckedContinuation { continuation in
            self.characteristicsContinuation = continuation
            
            // Timeout
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if let cont = self.characteristicsContinuation {
                    cont.resume(returning: [])
                    self.characteristicsContinuation = nil
                }
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            bluetoothState = central.state
            
            if central.state != .poweredOn {
                isScanning = false
                discoveredDevices.removeAll()
                connectedDevice = nil
                connectionState = .disconnected
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let device = BluetoothDevice(
            peripheral: peripheral,
            rssi: RSSI,
            advertisementData: advertisementData
        )
        
        print("BluetoothManager: Discovered device: \(peripheral.name ?? "Unknown") - ID: \(peripheral.identifier) - Xiaomi: \(device.isXiaomiScale)")
        
        Task { @MainActor in
            // Update or add device
            if let index = discoveredDevices.firstIndex(where: { $0.peripheral.identifier == peripheral.identifier }) {
                discoveredDevices[index] = device
            } else {
                discoveredDevices.append(device)
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectionState = .connected
            
            if let device = discoveredDevices.first(where: { $0.peripheral.identifier == peripheral.identifier }) {
                connectedDevice = device
            }
            
            connectionContinuation?.resume(returning: true)
            connectionContinuation = nil
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionState = .disconnected
            connectedDevice = nil
            
            connectionContinuation?.resume(returning: false)
            connectionContinuation = nil
        }
        
        print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionState = .disconnected
            connectedDevice = nil
        }
        
        if let error = error {
            print("Disconnected with error: \(error.localizedDescription)")
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("BluetoothManager: Error discovering characteristics: \(error.localizedDescription)")
                characteristicsContinuation?.resume(returning: [])
            } else {
                let chars = service.characteristics ?? []
                print("BluetoothManager: Discovered \(chars.count) characteristics for service \(service.uuid.uuidString)")
                for char in chars {
                    var props: [String] = []
                    if char.properties.contains(.read) { props.append("read") }
                    if char.properties.contains(.write) { props.append("write") }
                    if char.properties.contains(.writeWithoutResponse) { props.append("writeWithoutResponse") }
                    if char.properties.contains(.notify) { props.append("notify") }
                    if char.properties.contains(.indicate) { props.append("indicate") }
                    print("  - \(char.uuid.uuidString): \(props.joined(separator: ", "))")
                }
                characteristicsContinuation?.resume(returning: chars)
            }
            characteristicsContinuation = nil
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("BluetoothManager: Error updating value: \(error.localizedDescription)")
            return
        }
        
        // Always log data updates for debugging
        let dataString = characteristic.value?.hexEncodedString() ?? "nil"
        print("=====================================")
        print("BluetoothManager: DATA RECEIVED!")
        print("  From: \(peripheral.name ?? "Unknown")")
        print("  Characteristic: \(characteristic.uuid.uuidString)")
        print("  Service: \(characteristic.service?.uuid.uuidString ?? "Unknown")")
        print("  Data (hex): \(dataString)")
        if let data = characteristic.value {
            print("  Data length: \(data.count) bytes")
            // Log first few bytes as integers
            if data.count >= 2 {
                let bytes = [UInt8](data)
                print("  First bytes: \(bytes.prefix(min(8, data.count)).map { String(format: "%02X", $0) }.joined(separator: " "))")
            }
        }
        print("=====================================")
        
        // Notify XiaomiScaleService of data update
        NotificationCenter.default.post(
            name: .bluetoothCharacteristicUpdated,
            object: nil,
            userInfo: [
                "peripheral": peripheral,
                "characteristic": characteristic,
                "value": characteristic.value as Any
            ]
        )
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("BluetoothManager: Error writing value to \(characteristic.uuid.uuidString): \(error.localizedDescription)")
        } else {
            print("BluetoothManager: Successfully wrote value to characteristic \(characteristic.uuid.uuidString)")
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("BluetoothManager: Error updating notification state: \(error.localizedDescription)")
        } else {
            print("BluetoothManager: Notification state updated for \(characteristic.uuid.uuidString) - isNotifying: \(characteristic.isNotifying)")
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let bluetoothCharacteristicUpdated = Notification.Name("bluetoothCharacteristicUpdated")
}