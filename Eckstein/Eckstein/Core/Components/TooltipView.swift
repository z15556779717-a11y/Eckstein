//
//  TooltipView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 23/07/2025.
//

import SwiftUI

enum TooltipPosition {
    case above
    case below
    case leading
    case trailing
}

struct TooltipView: View {
    let text: String
    let tipId: String
    let position: TooltipPosition
    var onDismiss: (() -> Void)?
    
    @StateObject private var tipManager = TipManager.shared
    @State private var isVisible = false
    @State private var dismissTimer: Timer?
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var arrowEdge: Edge {
        switch position {
        case .above: return .bottom
        case .below: return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }
    
    var body: some View {
        if tipManager.shouldShowTip(tipId) && isVisible {
            VStack(spacing: 0) {
                if position == .below {
                    ArrowShape(edge: arrowEdge)
                        .fill(Color(.systemGray6))
                        .frame(width: 20, height: 10)
                }
                
                HStack {
                    Text(text)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer(minLength: 8)
                    
                    Button(action: dismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 18))
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                if position == .above {
                    ArrowShape(edge: arrowEdge)
                        .fill(Color(.systemGray6))
                        .frame(width: 20, height: 10)
                }
            }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            ))
            .onAppear {
                startDismissTimer()
            }
            .onDisappear {
                dismissTimer?.invalidate()
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        tipManager.markTipAsSeen(tipId)
        onDismiss?()
        dismissTimer?.invalidate()
    }
    
    private func startDismissTimer() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            dismiss()
        }
    }
    
    func show() {
        withAnimation(.easeIn(duration: 0.3)) {
            isVisible = true
        }
    }
}

// MARK: - Arrow Shape

struct ArrowShape: Shape {
    let edge: Edge
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch edge {
        case .top:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        case .bottom:
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        case .leading:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        case .trailing:
            path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        
        return path
    }
}

// Extension moved to TooltipModifier.swift to avoid duplication

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        Text("Tap me!")
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .overlay(
                TooltipView(
                    text: "This is a helpful tip that explains what this button does.",
                    tipId: "preview_tip",
                    position: .below
                )
                .onAppear {
                    // For preview, show immediately
                }
            )
        
        Spacer()
    }
    .padding()
}