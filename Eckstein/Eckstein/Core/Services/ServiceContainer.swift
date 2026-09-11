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
        // The shared instance, not a second one. Two repositories over the same
        // context would each hold their own `weightEntries` / `currentWeight`
        // cache, and the Dashboard, the Weight tab and the Profile summary would
        // then be able to disagree about the user's current weight.
        self.weightRepository = WeightRepository.shared
        
        // Bluetooth services
        self.bluetoothManager = BluetoothManager.shared
        self.scaleService = XiaomiScaleService.shared
    }
}