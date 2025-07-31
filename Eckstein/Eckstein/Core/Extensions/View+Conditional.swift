//
//  View+Conditional.swift
//  Eckstein
//
//  Created by Eliad Shahar on 23/07/2025.
//

import SwiftUI

extension View {
    /// Conditionally applies a transformation to the view
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Conditionally applies one of two transformations to the view
    @ViewBuilder
    func `if`<TrueTransform: View, FalseTransform: View>(
        _ condition: Bool,
        transform: (Self) -> TrueTransform,
        else elseTransform: (Self) -> FalseTransform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            elseTransform(self)
        }
    }
}