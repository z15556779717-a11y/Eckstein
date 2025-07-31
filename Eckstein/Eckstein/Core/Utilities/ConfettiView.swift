//
//  ConfettiView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 14/07/2025.
//

import SwiftUI

struct ConfettiView: View {
    @State private var confettiIsActive = false
    @State private var confettiOpacity = 1.0
    let confettiCount = 100
    let duration: Double = 3.0
    
    var body: some View {
        ZStack {
            ForEach(0..<confettiCount, id: \.self) { index in
                ConfettiPiece(index: index, isActive: $confettiIsActive)
            }
        }
        .opacity(confettiOpacity)
        .onAppear {
            confettiIsActive = true
            
            // Fade out after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + duration - 0.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    confettiOpacity = 0
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct ConfettiPiece: View {
    let index: Int
    @Binding var isActive: Bool
    @State private var xPosition: CGFloat = 0
    @State private var yPosition: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1
    
    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
    private let shapes = ["circle", "square", "triangle"]
    
    private var randomColor: Color {
        colors[index % colors.count]
    }
    
    private var randomShape: String {
        shapes[index % shapes.count]
    }
    
    private var startX: CGFloat {
        CGFloat.random(in: -UIScreen.main.bounds.width/2...UIScreen.main.bounds.width/2)
    }
    
    private var endX: CGFloat {
        startX + CGFloat.random(in: -100...100)
    }
    
    private var endY: CGFloat {
        UIScreen.main.bounds.height + 100
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if randomShape == "circle" {
                    Circle()
                        .fill(randomColor)
                        .frame(width: 10, height: 10)
                } else if randomShape == "square" {
                    Rectangle()
                        .fill(randomColor)
                        .frame(width: 8, height: 8)
                } else {
                    Triangle()
                        .fill(randomColor)
                        .frame(width: 10, height: 10)
                }
            }
            .position(x: geometry.size.width/2 + xPosition, y: yPosition)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .opacity(isActive ? 1 : 0)
            .onAppear {
                xPosition = startX
                yPosition = -50
                rotation = Double.random(in: 0...360)
                scale = CGFloat.random(in: 0.5...1.5)
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    withAnimation(.easeOut(duration: Double.random(in: 2.5...3.5))) {
                        xPosition = endX
                        yPosition = endY
                        rotation += Double.random(in: 360...720) * (Bool.random() ? 1 : -1)
                    }
                }
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// Preview
struct ConfettiView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.white
            ConfettiView()
        }
    }
}