//
//  ServiceContainer.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import CoreData

@MainActor
class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()
    
    let persistenceController: PersistenceController
    let supabaseService: SupabaseService
    let workoutRepository: WorkoutRepository
    let dietRepository: DietRepository
    let weightRepository: WeightRepository
    let scaleService: XiaomiScaleService
    let bluetoothManager: BluetoothManager
    
    private init() {
        self.persistenceController = PersistenceController.shared
        self.supabaseService = SupabaseService.shared
        
        let context = persistenceController.container.viewContext
        self.workoutRepository = WorkoutRepository(context: context)
        self.dietRepository = DietRepository(context: context)
        self.weightRepository = WeightRepository(context: context)
        
        // Bluetooth services
        self.bluetoothManager = BluetoothManager.shared
        self.scaleService = XiaomiScaleService.shared
    }
}