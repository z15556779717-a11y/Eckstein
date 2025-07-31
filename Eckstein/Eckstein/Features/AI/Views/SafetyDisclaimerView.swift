//
//  SafetyDisclaimerView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI

struct SafetyDisclaimerView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasAcceptedAIDisclaimer") private var hasAccepted = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("AI Coach Disclaimer")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom)
                    
                    // Disclaimer Text
                    VStack(alignment: .leading, spacing: 16) {
                        DisclaimerSection(
                            title: "Medical Disclaimer",
                            content: "The AI Coach is not a substitute for professional medical advice, diagnosis, or treatment. Always consult with qualified healthcare providers before beginning any fitness or nutrition program."
                        )
                        
                        DisclaimerSection(
                            title: "Fitness Guidance",
                            content: "Exercise recommendations are general in nature. Consider your individual fitness level, health conditions, and limitations. Stop immediately if you experience pain, dizziness, or discomfort."
                        )
                        
                        DisclaimerSection(
                            title: "Nutrition Advice",
                            content: "Dietary suggestions are for informational purposes only. Individual nutritional needs vary. Consult a registered dietitian for personalized meal planning, especially if you have allergies or medical conditions."
                        )
                        
                        DisclaimerSection(
                            title: "AI Limitations",
                            content: "AI responses are generated based on patterns in data and may not always be accurate or appropriate for your specific situation. Use your judgment and verify important information."
                        )
                        
                        DisclaimerSection(
                            title: "Emergency Situations",
                            content: "In case of injury or medical emergency, stop exercising immediately and seek professional medical help. Do not rely on AI advice for urgent health matters."
                        )
                    }
                    
                    // Acceptance
                    VStack(spacing: 16) {
                        Text("By using the AI Coach, you acknowledge that you have read and understood this disclaimer.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            hasAccepted = true
                            isPresented = false
                        } label: {
                            Text("I Understand and Accept")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        
                        Button {
                            isPresented = false
                        } label: {
                            Text("Cancel")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}

struct DisclaimerSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Disclaimer Check Modifier

struct DisclaimerCheckModifier: ViewModifier {
    @AppStorage("hasAcceptedAIDisclaimer") private var hasAccepted = false
    @State private var showDisclaimer = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if !hasAccepted {
                    showDisclaimer = true
                }
            }
            .sheet(isPresented: $showDisclaimer) {
                SafetyDisclaimerView(isPresented: $showDisclaimer)
            }
    }
}

extension View {
    func checkAIDisclaimer() -> some View {
        modifier(DisclaimerCheckModifier())
    }
}