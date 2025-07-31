//
//  DataValidationView.swift
//  Eckstein
//
//  Created by Assistant on 15/07/2025.
//

import SwiftUI
import CoreData

struct DataValidationView: View {
    @State private var validationResult = ""
    @State private var isValidating = false
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Data Validation")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Check what data is being sent to sync")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Validate Sync Data") {
                        validateData()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isValidating)
                    
                    if isValidating {
                        ProgressView()
                    }
                    
                    ScrollView {
                        Text(validationResult)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 400)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func validateData() {
        isValidating = true
        validationResult = "=== Data Validation ===\n\n"
        
        // Check CDEcksteinMeal entities
        let mealRequest = CDEcksteinMeal.fetchRequest()
        mealRequest.fetchLimit = 5
        
        do {
            let meals = try viewContext.fetch(mealRequest)
            validationResult += "Found \(meals.count) meals in Core Data\n\n"
            
            for (index, meal) in meals.enumerated() {
                validationResult += "Meal \(index + 1):\n"
                validationResult += "  ID: \(meal.id?.uuidString ?? "nil")\n"
                validationResult += "  User ID: \(meal.user?.id?.uuidString ?? "nil")\n"
                validationResult += "  Date: \(meal.date?.description ?? "nil")\n"
                validationResult += "  Meal Number: \(meal.mealNumber) (type: \(type(of: meal.mealNumber)))\n"
                
                // Encode the meal as sync would
                if let encodedData = encodeMeal(meal) {
                    validationResult += "  Encoded JSON:\n"
                    if let jsonString = String(data: encodedData, encoding: .utf8) {
                        validationResult += "  \(jsonString)\n"
                    }
                    
                    // Validate JSON
                    do {
                        if let json = try JSONSerialization.jsonObject(with: encodedData) as? [String: Any] {
                            validationResult += "  ✅ Valid JSON\n"
                            
                            // Check specific fields
                            if let mealNumber = json["meal_number"] as? Int {
                                if mealNumber == 1 || mealNumber == 2 {
                                    validationResult += "  ✅ Valid meal_number: \(mealNumber)\n"
                                } else {
                                    validationResult += "  ❌ Invalid meal_number: \(mealNumber) (must be 1 or 2)\n"
                                }
                            } else {
                                validationResult += "  ❌ meal_number not found or wrong type\n"
                            }
                        }
                    } catch {
                        validationResult += "  ❌ JSON parsing error: \(error)\n"
                    }
                }
                
                validationResult += "\n"
            }
            
            // Check for test user
            let userRequest = CDUser.fetchRequest()
            userRequest.predicate = NSPredicate(format: "id == %@", UUID(uuidString: "00000000-0000-0000-0000-000000000001")! as CVarArg)
            
            let users = try viewContext.fetch(userRequest)
            if users.isEmpty {
                validationResult += "⚠️  Test user not found in Core Data\n"
            } else {
                validationResult += "✅ Test user exists\n"
            }
            
        } catch {
            validationResult += "❌ Error fetching data: \(error)\n"
        }
        
        isValidating = false
    }
    
    private func encodeMeal(_ meal: CDEcksteinMeal) -> Data? {
        var dict: [String: Any] = [:]
        let dateFormatter = ISO8601DateFormatter()
        
        dict["id"] = meal.id?.uuidString
        dict["user_id"] = meal.user?.id?.uuidString ?? "00000000-0000-0000-0000-000000000001"
        
        if let date = meal.date {
            let dateOnlyFormatter = DateFormatter()
            dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
            dateOnlyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            dict["date"] = dateOnlyFormatter.string(from: date)
        }
        
        dict["meal_number"] = Int(meal.mealNumber)
        dict["total_calories"] = 0
        dict["total_protein"] = 0.0
        dict["total_carbs"] = 0.0
        dict["total_fat"] = 0.0
        dict["created_at"] = meal.date != nil ? dateFormatter.string(from: meal.date!) : dateFormatter.string(from: Date())
        dict["updated_at"] = dateFormatter.string(from: Date())
        
        return try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
    }
}

#Preview {
    DataValidationView()
}