//
//  CDUser+CoreDataProperties.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//
//

import Foundation
import CoreData


extension CDUser {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDUser> {
        return NSFetchRequest<CDUser>(entityName: "CDUser")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var email: String?
    @NSManaged public var fullName: String?
    @NSManaged public var gender: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncStatus: String?
    @NSManaged public var lastSyncedAt: Date?
    @NSManaged public var preferences: CDUserPreferences?
    @NSManaged public var workouts: NSSet?
    @NSManaged public var meals: NSSet?
    @NSManaged public var weightEntries: NSSet?
    @NSManaged public var calorieBanks: NSSet?
    @NSManaged public var ecksteinMeals: NSSet?
    @NSManaged public var workoutTypes: NSSet?
    @NSManaged public var milkConsumptions: NSSet?
    @NSManaged public var fatMealTrackers: NSSet?
    @NSManaged public var carbLoadTrackers: NSSet?

}

// MARK: Generated accessors for workouts
extension CDUser {

    @objc(addWorkoutsObject:)
    @NSManaged public func addToWorkouts(_ value: CDWorkout)

    @objc(removeWorkoutsObject:)
    @NSManaged public func removeFromWorkouts(_ value: CDWorkout)

    @objc(addWorkouts:)
    @NSManaged public func addToWorkouts(_ values: NSSet)

    @objc(removeWorkouts:)
    @NSManaged public func removeFromWorkouts(_ values: NSSet)

}

// MARK: Generated accessors for meals
extension CDUser {

    @objc(addMealsObject:)
    @NSManaged public func addToMeals(_ value: CDMeal)

    @objc(removeMealsObject:)
    @NSManaged public func removeFromMeals(_ value: CDMeal)

    @objc(addMeals:)
    @NSManaged public func addToMeals(_ values: NSSet)

    @objc(removeMeals:)
    @NSManaged public func removeFromMeals(_ values: NSSet)

}

// MARK: Generated accessors for weightEntries
extension CDUser {

    @objc(addWeightEntriesObject:)
    @NSManaged public func addToWeightEntries(_ value: CDWeightEntry)

    @objc(removeWeightEntriesObject:)
    @NSManaged public func removeFromWeightEntries(_ value: CDWeightEntry)

    @objc(addWeightEntries:)
    @NSManaged public func addToWeightEntries(_ values: NSSet)

    @objc(removeWeightEntries:)
    @NSManaged public func removeFromWeightEntries(_ values: NSSet)

}

// MARK: Generated accessors for calorieBanks
extension CDUser {

    @objc(addCalorieBanksObject:)
    @NSManaged public func addToCalorieBanks(_ value: CDCalorieBank)

    @objc(removeCalorieBanksObject:)
    @NSManaged public func removeFromCalorieBanks(_ value: CDCalorieBank)

    @objc(addCalorieBanks:)
    @NSManaged public func addToCalorieBanks(_ values: NSSet)

    @objc(removeCalorieBanks:)
    @NSManaged public func removeFromCalorieBanks(_ values: NSSet)

}

// MARK: Generated accessors for ecksteinMeals
extension CDUser {

    @objc(addEcksteinMealsObject:)
    @NSManaged public func addToEcksteinMeals(_ value: CDEcksteinMeal)

    @objc(removeEcksteinMealsObject:)
    @NSManaged public func removeFromEcksteinMeals(_ value: CDEcksteinMeal)

    @objc(addEcksteinMeals:)
    @NSManaged public func addToEcksteinMeals(_ values: NSSet)

    @objc(removeEcksteinMeals:)
    @NSManaged public func removeFromEcksteinMeals(_ values: NSSet)

}

// MARK: Generated accessors for workoutTypes
extension CDUser {

    @objc(addWorkoutTypesObject:)
    @NSManaged public func addToWorkoutTypes(_ value: CDWorkoutType)

    @objc(removeWorkoutTypesObject:)
    @NSManaged public func removeFromWorkoutTypes(_ value: CDWorkoutType)

    @objc(addWorkoutTypes:)
    @NSManaged public func addToWorkoutTypes(_ values: NSSet)

    @objc(removeWorkoutTypes:)
    @NSManaged public func removeFromWorkoutTypes(_ values: NSSet)

}

// MARK: Generated accessors for milkConsumptions
extension CDUser {

    @objc(addMilkConsumptionsObject:)
    @NSManaged public func addToMilkConsumptions(_ value: CDMilkConsumption)

    @objc(removeMilkConsumptionsObject:)
    @NSManaged public func removeFromMilkConsumptions(_ value: CDMilkConsumption)

    @objc(addMilkConsumptions:)
    @NSManaged public func addToMilkConsumptions(_ values: NSSet)

    @objc(removeMilkConsumptions:)
    @NSManaged public func removeFromMilkConsumptions(_ values: NSSet)

}

// MARK: Generated accessors for fatMealTrackers
extension CDUser {

    @objc(addFatMealTrackersObject:)
    @NSManaged public func addToFatMealTrackers(_ value: CDFatMealTracker)

    @objc(removeFatMealTrackersObject:)
    @NSManaged public func removeFromFatMealTrackers(_ value: CDFatMealTracker)

    @objc(addFatMealTrackers:)
    @NSManaged public func addToFatMealTrackers(_ values: NSSet)

    @objc(removeFatMealTrackers:)
    @NSManaged public func removeFromFatMealTrackers(_ values: NSSet)

}

// MARK: Generated accessors for carbLoadTrackers
extension CDUser {

    @objc(addCarbLoadTrackersObject:)
    @NSManaged public func addToCarbLoadTrackers(_ value: CDCarbLoadTracker)

    @objc(removeCarbLoadTrackersObject:)
    @NSManaged public func removeFromCarbLoadTrackers(_ value: CDCarbLoadTracker)

    @objc(addCarbLoadTrackers:)
    @NSManaged public func addToCarbLoadTrackers(_ values: NSSet)

    @objc(removeCarbLoadTrackers:)
    @NSManaged public func removeFromCarbLoadTrackers(_ values: NSSet)

}

extension CDUser : Identifiable {

}