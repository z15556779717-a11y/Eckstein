//
//  NetworkMonitor.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import Network
import Combine

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.eckstein.networkmonitor")
    
    @Published private(set) var isConnected = false
    @Published private(set) var connectionType: ConnectionType = .unknown
    @Published private(set) var isExpensive = false
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    private init() {
        print("NetworkMonitor: Initializing...")
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                self?.updateConnectionType(path)
                
                if path.status == .satisfied {
                    self?.notifyConnectionRestored()
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func updateConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
    
    private func notifyConnectionRestored() {
        NotificationCenter.default.post(
            name: .networkConnectionRestored,
            object: nil
        )
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    // Check if we should sync based on user preferences
    func shouldSync(wifiOnly: Bool) -> Bool {
        print("NetworkMonitor.shouldSync() - Connected: \(isConnected), Type: \(connectionType), WiFiOnly: \(wifiOnly)")
        
        guard isConnected else { 
            print("NetworkMonitor: Not connected to network")
            return false 
        }
        
        if wifiOnly {
            let canSync = connectionType == .wifi || connectionType == .ethernet
            print("NetworkMonitor: WiFi-only mode - Can sync: \(canSync)")
            return canSync
        }
        
        print("NetworkMonitor: Can sync on any connection")
        return true
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let networkConnectionRestored = Notification.Name("networkConnectionRestored")
}