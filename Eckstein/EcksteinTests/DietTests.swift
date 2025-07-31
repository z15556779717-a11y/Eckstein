//
//  DietTests.swift
//  EcksteinTests
//
//  Created by Eliad Shahar on 13/07/2025.
//

import XCTest
import CoreData
@testable import Eckstein

class DietTests: XCTestCase {
    var controller: PersistenceController!
    var context: NSManagedObjectContext!
    var repository: DietRepository!
    var calorieBank: CalorieBankManager!
    
    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        repository = DietRepository(context: context)
        calorieBank = CalorieBankManager(context: context)
    }
    
    override func tearDown() {
        controller = nil
        context = nil
        repository = nil
        calorieBank = nil
        super.tearDown()
    }
    
    // MARK: - Food Creation Tests
    
    func testCreateFood() {
        let food = repository.createFood(
            name: "Apple",
            brand: "Generic",
            calories: 95,
            protein: 0.5,
            carbs: 25,
            fats: 0.3,
            servingSize: 182,
            servingUnit: "g"
        )
        
        XCTAssertNotNil(food)
        XCTAssertEqual(food.name, "Apple")
        XCTAssertEqual(food.calories, 95)
        XCTAssertEqual(food.servingSize, 182)
    }
    
    func testFoodSearch() {
        // Create test foods
        _ = repository.createFood(name: "Banana", brand: nil, calories: 105, protein: 1.3, carbs: 27, fats: 0.4)
        _ = repository.createFood(name: "Banana Bread", brand: "Homemade", calories: 196, protein: 2.6, carbs: 33, fats: 6)
        _ = repository.createFood(name: "Apple", brand: nil, calories: 95, protein: 0.5, carbs: 25, fats: 0.3)
        
        let bananaFoods = repository.searchFoods(query: "banana")
        XCTAssertEqual(bananaFoods.count, 2)
        
        let allFoods = repository.searchFoods(query: "")
        XCTAssertEqual(allFoods.count, 3)
    }
    
    // MARK: - Meal Management Tests
    
    func testCreateMeal() {
        let meal = repository.createMeal(type: .lunch)
        
        XCTAssertNotNil(meal.id)
        XCTAssertEqual(meal.type, "lunch")
        XCTAssertNotNil(meal.date)
        XCTAssertEqual(meal.totalCalories, 0)
    }
    
    func testAddFoodToMeal() {
        let meal = repository.createMeal(type: .breakfast)
        let food = repository.createFood(
            name: "Oatmeal",
            brand: nil,
            calories: 150,
            protein: 5,
            carbs: 27,
            fats: 3
        )
        
        let mealItem = repository.addFoodToMeal(
            meal: meal,
            food: food,
            quantity: 1.5
        )
        
        XCTAssertNotNil(mealItem)
        XCTAssertEqual(mealItem.quantity, 1.5)
        XCTAssertEqual(meal.totalCalories, 225) // 150 * 1.5
        XCTAssertEqual(meal.totalProtein, 7.5) // 5 * 1.5
    }
    
    func testMealCalculations() {
        let meal = repository.createMeal(type: .dinner)
        
        let foods = [
            ("Chicken Breast", 165.0, 31.0, 0.0, 3.6, 100.0),
            ("Brown Rice", 216.0, 5.0, 45.0, 1.8, 100.0),
            ("Broccoli", 55.0, 3.7, 11.0, 0.6, 100.0)
        ]
        
        for (name, calories, protein, carbs, fats, serving) in foods {
            let food = repository.createFood(
                name: name,
                brand: nil,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fats: fats,
                servingSize: serving,
                servingUnit: "g"
            )
            
            _ = repository.addFoodToMeal(meal: meal, food: food, quantity: 1)
        }
        
        XCTAssertEqual(meal.totalCalories, 436) // Sum of all calories
        XCTAssertEqual(meal.totalProtein, 39.7) // Sum of all protein
        XCTAssertEqual(meal.totalCarbs, 56) // Sum of all carbs
        XCTAssertEqual(meal.totalFats, 6) // Sum of all fats
    }
    
    // MARK: - Calorie Bank Tests
    
    func testCalorieBankDeposit() {
        let result = calorieBank.deposit(
            calories: 200,
            reason: "Skipped dessert"
        )
        
        XCTAssertTrue(result)
        XCTAssertEqual(calorieBank.currentBalance(), 200)
    }
    
    func testCalorieBankWithdrawal() {
        // First deposit
        _ = calorieBank.deposit(calories: 500, reason: "Extra workout")
        
        // Then withdraw
        let result = calorieBank.withdraw(
            calories: 300,
            reason: "Pizza night"
        )
        
        XCTAssertTrue(result)
        XCTAssertEqual(calorieBank.currentBalance(), 200)
    }
    
    func testCalorieBankInsufficientFunds() {
        _ = calorieBank.deposit(calories: 100, reason: "Small deposit")
        
        let result = calorieBank.withdraw(calories: 200, reason: "Too much")
        
        XCTAssertFalse(result)
        XCTAssertEqual(calorieBank.currentBalance(), 100)
    }
    
    func testCalorieBankHistory() {
        _ = calorieBank.deposit(calories: 300, reason: "Morning run")
        _ = calorieBank.withdraw(calories: 100, reason: "Extra snack")
        _ = calorieBank.deposit(calories: 200, reason: "Skipped lunch")
        
        let transactions = calorieBank.getTransactions(for: .week)
        XCTAssertEqual(transactions.count, 3)
        XCTAssertEqual(calorieBank.currentBalance(), 400)
    }
    
    // MARK: - Nutrition Calculations Tests
    
    func testNutritionCalculations() {
        let calculator = NutritionCalculator()
        
        // Test calorie goals
        let goals = calculator.calculateDailyCalories(
            weight: 70,
            height: 175,
            age: 30,
            gender: .male,
            activityLevel: .moderate,
            goal: .maintain
        )
        
        XCTAssertGreaterThan(goals.calories, 2000)
        XCTAssertGreaterThan(goals.protein, 50)
        XCTAssertGreaterThan(goals.carbs, 200)
        XCTAssertGreaterThan(goals.fats, 50)
    }
    
    func testServingSizeCalculation() {
        let calculator = ServingSizeCalculator()
        
        // Test unit conversions
        let grams = calculator.convertToGrams(100, unit: "oz")
        XCTAssertEqual(grams, 2834.95, accuracy: 0.01)
        
        let cups = calculator.convertFromGrams(240, toUnit: "cup")
        XCTAssertEqual(cups, 1, accuracy: 0.1)
    }
    
    // MARK: - Daily Summary Tests
    
    func testDailySummary() {
        // Create meals for today
        let meals: [(MealType, Double)] = [
            (.breakfast, 400),
            (.lunch, 600),
            (.dinner, 800),
            (.snack, 200)
        ]
        
        for (type, calories) in meals {
            let meal = repository.createMeal(type: type)
            let food = repository.createFood(
                name: "\(type) food",
                brand: nil,
                calories: calories,
                protein: calories * 0.1,
                carbs: calories * 0.4,
                fats: calories * 0.05
            )
            _ = repository.addFoodToMeal(meal: meal, food: food, quantity: 1)
        }
        
        let todayMeals = repository.fetchMeals(for: .today)
        let totalCalories = todayMeals.reduce(0) { $0 + Int($1.totalCalories) }
        
        XCTAssertEqual(todayMeals.count, 4)
        XCTAssertEqual(totalCalories, 2000)
    }
    
    // MARK: - Food Database Tests
    
    func testPreloadedFoods() {
        let foodData = FoodData()
        let commonFoods = foodData.commonFoods
        
        XCTAssertFalse(commonFoods.isEmpty)
        XCTAssertTrue(commonFoods.contains { $0.name == "Apple" })
        XCTAssertTrue(commonFoods.contains { $0.name == "Banana" })
    }
    
    func testFoodCategories() {
        let categories = ["Fruits", "Vegetables", "Proteins", "Grains", "Dairy", "Fats", "Snacks", "Beverages"]
        
        for category in categories {
            XCTAssertTrue(FoodCategory.allCases.map { $0.rawValue }.contains(category))
        }
    }
    
    // MARK: - Barcode Integration Tests
    
    func testBarcodeStorage() {
        let food = repository.createFood(
            name: "Protein Bar",
            brand: "Test Brand",
            calories: 200,
            protein: 20,
            carbs: 25,
            fats: 8,
            barcode: "1234567890"
        )
        
        XCTAssertEqual(food.barcode, "1234567890")
        
        let foundFood = repository.searchFoods(query: "1234567890").first
        XCTAssertEqual(foundFood?.name, "Protein Bar")
    }
}