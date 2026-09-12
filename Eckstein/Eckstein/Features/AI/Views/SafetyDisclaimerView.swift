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
                        
                        Text("ai_disclaimer_title".localized)
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom)
                    
                    // Disclaimer Text
                    VStack(alignment: .leading, spacing: 16) {
                        DisclaimerSection(
                            title: "ai_disclaimer_medical_title".localized,
                            content: "ai_disclaimer_medical_body".localized
                        )

                        DisclaimerSection(
                            title: "ai_disclaimer_fitness_title".localized,
                            content: "ai_disclaimer_fitness_body".localized
                        )

                        DisclaimerSection(
                            title: "ai_disclaimer_nutrition_title".localized,
                            content: "ai_disclaimer_nutrition_body".localized
                        )

                        DisclaimerSection(
                            title: "ai_disclaimer_limitations_title".localized,
                            content: "ai_disclaimer_limitations_body".localized
                        )

                        DisclaimerSection(
                            title: "ai_disclaimer_emergency_title".localized,
                            content: "ai_disclaimer_emergency_body".localized
                        )
                    }
                    
                    // Acceptance
                    VStack(spacing: 16) {
                        Text("ai_disclaimer_acknowledgement".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            hasAccepted = true
                            isPresented = false
                        } label: {
                            Text("ai_disclaimer_accept".localized)
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
                            Text("cancel".localized)
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