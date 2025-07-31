//
//  TooltipModifier.swift
//  Eckstein
//
//  Created by Eliad Shahar on 23/07/2025.
//

import SwiftUI

struct TooltipModifier: ViewModifier {
    let text: String
    let tipId: String
    let position: TooltipPosition
    
    @StateObject private var tipManager = TipManager.shared
    @State private var showTooltip = false
    @State private var dismissTask: Task<Void, Never>?
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: position.overlayAlignment) {
                if showTooltip && tipManager.shouldShowTip(tipId) {
                    TooltipPopup(
                        text: text,
                        position: position,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showTooltip = false
                            }
                            tipManager.markTipAsSeen(tipId)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8, anchor: position.scaleAnchor)
                            .combined(with: .opacity),
                        removal: .scale(scale: 0.8, anchor: position.scaleAnchor)
                            .combined(with: .opacity)
                    ))
                    .zIndex(999)
                }
            }
            .onAppear {
                // Show tooltip after a short delay
                if tipManager.shouldShowTip(tipId) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeIn(duration: 0.3)) {
                            showTooltip = true
                        }
                        
                        // Auto-dismiss after 5 seconds
                        dismissTask?.cancel()
                        dismissTask = Task {
                            try? await Task.sleep(nanoseconds: 5_000_000_000)
                            if !Task.isCancelled {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showTooltip = false
                                }
                                tipManager.markTipAsSeen(tipId)
                            }
                        }
                    }
                }
            }
            .onDisappear {
                dismissTask?.cancel()
            }
    }
}

struct TooltipPopup: View {
    let text: String
    let position: TooltipPosition
    let onDismiss: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if position == .below {
                Arrow(pointing: .up)
                    .fill(Color(.systemGray6))
                    .frame(width: 20, height: 10)
                    .offset(y: 1)
            }
            
            HStack(spacing: 12) {
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 280)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            
            if position == .above {
                Arrow(pointing: .down)
                    .fill(Color(.systemGray6))
                    .frame(width: 20, height: 10)
                    .offset(y: -1)
            }
        }
        .padding(position.edgePadding)
    }
}

struct Arrow: Shape {
    enum Direction {
        case up, down, left, right
    }
    
    let pointing: Direction
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch pointing {
        case .up:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .down:
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .left:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .right:
            path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        
        path.closeSubpath()
        return path
    }
}

extension TooltipPosition {
    var overlayAlignment: Alignment {
        switch self {
        case .above: return .top
        case .below: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
    
    var scaleAnchor: UnitPoint {
        switch self {
        case .above: return .bottom
        case .below: return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }
    
    var edgePadding: EdgeInsets {
        switch self {
        case .above: return EdgeInsets(top: 0, leading: 20, bottom: 10, trailing: 20)
        case .below: return EdgeInsets(top: 10, leading: 20, bottom: 0, trailing: 20)
        case .leading: return EdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 10)
        case .trailing: return EdgeInsets(top: 20, leading: 10, bottom: 20, trailing: 0)
        }
    }
}

// MARK: - View Extension

extension View {
    func tooltip(_ text: String, tipId: String, position: TooltipPosition = .below) -> some View {
        self.modifier(TooltipModifier(text: text, tipId: tipId, position: position))
    }
}