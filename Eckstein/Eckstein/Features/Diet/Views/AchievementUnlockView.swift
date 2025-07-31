//
//  AchievementUnlockView.swift
//  Eckstein
//
//  Created by Assistant on 17/01/2025.
//

import SwiftUI

struct AchievementUnlockView: View {
    let achievement: Achievement
    @Binding var isPresented: Bool
    @State private var animationScale = 0.5
    @State private var opacity = 0.0
    @State private var confettiTrigger = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Confetti effect (simple implementation)
            ZStack {
                ForEach(0..<20, id: \.self) { i in
                    AchievementConfettiPiece()
                        .position(
                            x: CGFloat.random(in: 50...350),
                            y: CGFloat.random(in: -50...50)
                        )
                        .animation(
                            Animation.easeOut(duration: 2)
                                .delay(Double(i) * 0.05),
                            value: confettiTrigger
                        )
                }
            }
            .frame(height: 100)
            .opacity(confettiTrigger > 0 ? 1 : 0)
            
            VStack(spacing: 16) {
                // Achievement icon
                ZStack {
                    Circle()
                        .fill(achievement.displayColor.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: achievement.icon)
                        .font(.system(size: 50))
                        .foregroundColor(achievement.displayColor)
                }
                .scaleEffect(animationScale)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animationScale)
                
                // Text content
                VStack(spacing: 8) {
                    Text("achievement_unlocked".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(achievement.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(achievement.displayColor)
                    
                    Text(achievement.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
                    .shadow(color: achievement.displayColor.opacity(0.3), radius: 20)
            )
        }
        .frame(maxWidth: 350)
        .opacity(opacity)
        .animation(.easeIn(duration: 0.3), value: opacity)
        .onAppear {
            animationScale = 1.0
            opacity = 1.0
            confettiTrigger = 1
            
            // Auto dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                dismissAnimation()
            }
        }
        .onTapGesture {
            dismissAnimation()
        }
    }
    
    private func dismissAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
}

struct AchievementConfettiPiece: View {
    @State private var offsetY: CGFloat = 0
    @State private var rotation = Double.random(in: 0...360)
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill([Color.red, .blue, .green, .yellow, .orange, .purple].randomElement()!)
            .frame(width: 10, height: 10)
            .rotationEffect(.degrees(rotation))
            .offset(y: offsetY)
            .onAppear {
                withAnimation(.linear(duration: 2)) {
                    offsetY = 400
                    rotation += Double.random(in: 180...720)
                }
            }
    }
}

// Preview
struct AchievementUnlockView_Previews: PreviewProvider {
    static var previews: some View {
        AchievementUnlockView(
            achievement: Achievement(
                id: "test",
                icon: "star.fill",
                titleKey: "achievement_first_day_title",
                descriptionKey: "achievement_first_day_desc",
                requirementKey: "achievement_first_day_req",
                color: "yellow",
                earnedDate: Date()
            ),
            isPresented: .constant(true)
        )
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}