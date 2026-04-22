//
//  MWButton.swift
//  Flashcards
//
//  Purpose: Convenience atom for the Modernist button trio (primary, secondary,
//           destructive). Wraps a SwiftUI `Button` and dispatches to the right
//           `.mwPrimary` / `.mwSecondary` / `.mwDestructive` ButtonStyle based
//           on a `Kind` enum, so call-sites that just need a labelled action
//           don't have to remember the style accessor. Where a SwiftUI `Button`
//           already exists in-place, prefer applying the style accessor directly
//           (`.buttonStyle(.mwPrimary)` et al.) over wrapping it in `MWButton`.
//  Dependencies: SwiftUI (View, Button, ViewBuilder), `MWPrimaryButtonStyle`,
//                `MWSecondaryButtonStyle`, `MWDestructiveButtonStyle`,
//                `MWSpacing` / `MWSpacingToken` via `mwPadding` (preview only),
//                `MWColor` (preview only).
//  Key concepts: Press animation, reduce-motion handling, control height, and
//                disabled-state colouring all live inside the underlying
//                ButtonStyles — `MWButton` itself is a pure dispatch wrapper
//                with no animation or layout logic of its own. The private
//                `apply` helper is a file-local utility that lets us branch
//                `.buttonStyle(...)` inside a `switch` without returning
//                different concrete types from each arm.
//

import SwiftUI

/// Primary/Secondary/Destructive button atom. Accepts label as a string or arbitrary view.
/// Use `.buttonStyle(.mwPrimary)` etc directly where a SwiftUI `Button` already exists;
/// this atom is for convenience when the call-site just needs a label.
public struct MWButton<Label: View>: View {
    /// The visual role of the button. Maps 1:1 to the `MW*ButtonStyle` trio.
    public enum Kind { case primary, secondary, destructive }

    let kind: Kind
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    /// Creates a button with an arbitrary `Label` view.
    /// - Parameters:
    ///   - kind: Which style to apply. Defaults to `.primary`.
    ///   - action: Invoked on tap.
    ///   - label: View builder producing the button's label.
    public init(_ kind: Kind = .primary, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.kind = kind
        self.action = action
        self.label = label
    }

    /// Renders a SwiftUI `Button` with the `Kind`-appropriate `MW*ButtonStyle` applied.
    public var body: some View {
        Button(action: action, label: label).apply {
            switch kind {
            case .primary: $0.buttonStyle(.mwPrimary)
            case .secondary: $0.buttonStyle(.mwSecondary)
            case .destructive: $0.buttonStyle(.mwDestructive)
            }
        }
    }
}

public extension MWButton where Label == Text {
    /// Convenience initializer for the common case of a plain-text label.
    /// - Parameters:
    ///   - title: The label text.
    ///   - kind: Which style to apply. Defaults to `.primary`.
    ///   - action: Invoked on tap.
    init(_ title: String, kind: Kind = .primary, action: @escaping () -> Void) {
        self.init(kind, action: action) { Text(title) }
    }
}

/// File-local helper that lets us branch `.buttonStyle(...)` inside a `switch`
/// while still returning a single opaque type from `body`.
private extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }
}

#Preview("MWButton variants") {
    VStack(spacing: MWSpacing.m) {
        MWButton("Continue") {}
        MWButton("Sign in with email", kind: .secondary) {}
        MWButton("Delete account", kind: .destructive) {}
    }
    .mwPadding(.all, .xl)
    .background(MWColor.canvas)
}
