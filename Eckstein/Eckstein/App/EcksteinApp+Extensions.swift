//
//  EcksteinApp+Extensions.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

extension EcksteinApp {
    func configureEnvironment() {
        // Force environment loader to initialize
        _ = EnvironmentLoader.shared
        
        // Log configuration status
        print("=== Eckstein Configuration ===")
        print("Supabase configured: \(AppEnvironment.isSupabaseConfigured)")
        print("============================")
        
        // Configure notification service
        NotificationService.shared.registerNotificationCategories()
        NotificationService.shared.checkAuthorizationStatus()
    }
    
    func seedInitialData() {
        let context = PersistenceController.shared.container.viewContext
        
        // Seed exercises if needed
        let workoutRepository = WorkoutRepository(context: context)
        workoutRepository.seedExercisesIfNeeded()
        print("Exercise seeding completed")
        
        // Seed the official nutrition catalog if needed.
        //
        // This replaced constructing a `DietRepository`, whose initialiser seeded
        // the legacy `CDFood` catalog. See NUTRITION_MIGRATION_PLAN.md §3.3.
        do {
            let seeded = try NutritionCatalogSeed.seedIfNeeded(context: context)
            print("Nutrition catalog seeding completed (\(seeded) rows)")

            // A store seeded before this phase already holds the diet-rule foods
            // with every nutrition column NULL, and the per-food seeding in
            // `CustomFoodManager` skips a row it can already see. This fills
            // those rows in once; it writes nothing on a fresh install, where
            // the rows do not exist yet, or on any later launch.
            let backfilled = try NutritionCatalogSeed.backfillDietRuleNutrition(context: context)
            if backfilled > 0 {
                print("Nutrition backfill completed (\(backfilled) rows)")
            }
        } catch {
            print("Error seeding the nutrition catalog: \(error)")
        }
    }
}