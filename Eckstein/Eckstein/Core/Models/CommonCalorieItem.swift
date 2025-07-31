//
//  CommonCalorieItem.swift
//  Eckstein
//
//  Created by Assistant on 14/07/2025.
//

import Foundation

struct CommonCalorieItem: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let calories: Int
    
    init(name: String, calories: Int) {
        self.id = UUID()
        self.name = name
        self.calories = calories
    }
    
    // Default common items
    static let defaultItems = [
        CommonCalorieItem(name: "Soy Sauce", calories: 30),
        CommonCalorieItem(name: "Oil (1 tbsp)", calories: 120),
        CommonCalorieItem(name: "Sugar (1 tsp)", calories: 16),
        CommonCalorieItem(name: "Ketchup", calories: 20),
        CommonCalorieItem(name: "Mayo (1 tbsp)", calories: 90),
        CommonCalorieItem(name: "Butter (1 tbsp)", calories: 100),
        CommonCalorieItem(name: "Honey (1 tbsp)", calories: 64),
        CommonCalorieItem(name: "Salad Dressing", calories: 75),
        CommonCalorieItem(name: "BBQ Sauce", calories: 30),
        CommonCalorieItem(name: "Hot Sauce", calories: 5)
    ]
}

// Manager for storing and retrieving common items
class CommonCalorieItemsManager: ObservableObject {
    @Published var items: [CommonCalorieItem] = []
    
    private let userDefaultsKey = "CommonCalorieItems"
    
    static let shared = CommonCalorieItemsManager()
    
    private init() {
        loadItems()
    }
    
    func loadItems() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([CommonCalorieItem].self, from: data) {
            items = decoded
        } else {
            // Use default items if none saved
            items = CommonCalorieItem.defaultItems
            saveItems()
        }
    }
    
    func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    func addItem(_ item: CommonCalorieItem) {
        items.append(item)
        saveItems()
    }
    
    func deleteItem(_ item: CommonCalorieItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }
    
    func resetToDefaults() {
        items = CommonCalorieItem.defaultItems
        saveItems()
    }
}