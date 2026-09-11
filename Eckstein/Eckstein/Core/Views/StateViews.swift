//
//  StateViews.swift
//  Eckstein
//
//  The three states every data-backed screen can be in — loading, empty, error —
//  in one place, so no screen invents its own spinner or its own blank page.
//
//  The rule this file exists to enforce is that a screen with nothing to show
//  says *why*. Before this, a failed fetch left the view bodies rendering an
//  empty list, which reads to a user as "you have no data" — a claim the app is
//  not in a position to make. `ErrorStateView` is the difference between "you
//  have logged nothing" and "we could not find out".
//

import SwiftUI

// MARK: - Loading

/// A centred spinner with a caption.
///
/// `minHeight` rather than a fixed frame: short enough to sit inside a card,
/// tall enough that a full-screen use does not jitter as it swaps to content.
struct LoadingStateView: View {
    var message: String = "loading".localized

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        // One element, not two: VoiceOver should say "Loading" once rather than
        // announce a spinner and then a label.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

// MARK: - Error

/// A failed load, with a way out.
///
/// `retry` is optional because not every failure is retryable, but a screen that
/// passes `nil` is saying the state is terminal — it still must not show a blank
/// page, which is why the description is required.
struct ErrorStateView: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("error".localized, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retry {
                Button("retry".localized, action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Empty

/// Nothing to show, and it is not a failure.
///
/// Wraps `ContentUnavailableView` so every empty state in the app has the same
/// shape and the caller supplies only what differs. The optional action is the
/// thing the user would do to make the state go away — "log your first weight"
/// rather than a dead end.
struct EmptyStateContent: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Container

/// Picks between loading, error and content.
///
/// A screen writes its success case once and hands the other two to this type,
/// so "forgot to handle the error branch" stops being possible — the error case
/// is a value it has to pass, not a branch it has to remember.
///
/// `isEmpty` is what separates "loaded, nothing there" from "loaded, here it
/// is": the caller knows its own emptiness condition (`entries.isEmpty`, say) and
/// this type cannot infer it.
struct LoadableContent<Content: View, Empty: View>: View {
    let isLoading: Bool
    let errorMessage: String?
    let isEmpty: Bool
    let retry: (() -> Void)?
    @ViewBuilder let content: () -> Content
    @ViewBuilder let empty: () -> Empty

    var body: some View {
        if isLoading {
            LoadingStateView()
        } else if let errorMessage {
            ErrorStateView(message: errorMessage, retry: retry)
        } else if isEmpty {
            empty()
        } else {
            content()
        }
    }
}

extension LoadableContent where Empty == EmptyView {
    /// For a screen whose empty case is not reached — e.g. a card that simply
    /// hides itself. `isEmpty` still has to be passed as `false`, so the choice
    /// is deliberate rather than an omission.
    init(
        isLoading: Bool,
        errorMessage: String?,
        isEmpty: Bool = false,
        retry: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            isLoading: isLoading,
            errorMessage: errorMessage,
            isEmpty: isEmpty,
            retry: retry,
            content: content,
            empty: { EmptyView() }
        )
    }
}

// MARK: - Inline card states

/// A one-line error for a card, where the full-page `ErrorStateView` would be
/// out of proportion.
struct InlineErrorLabel: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Loading") {
    LoadingStateView()
}

#Preview("Error") {
    ErrorStateView(message: "Something went wrong", retry: {})
}

#Preview("Empty") {
    EmptyStateContent(
        icon: "scalemass",
        title: "No weigh-ins yet",
        message: "Log your first weight to start a trend.",
        actionTitle: "Log Weight",
        action: {}
    )
}
