//
//  MWDestructiveButtonStyle.swift
//  Flashcards
//
//  Purpose: Destructive action button style — a text-only, "again"-colored
//           label used for irreversible or dangerous actions (e.g. "Delete
//           deck", "Reset progress"). Intentionally borderless and fill-less
//           to feel lighter than a primary button, while the warning color
//           still signals caution.
//  Dependencies: SwiftUI (ButtonStyle), `MWType`, `MWColor`, `MWMotion`.
//  Key concepts: No surface fill, no stroke, no corner radius — only a colored
//                label. Sits at 44pt (the Apple Human Interface minimum tap
//                target) rather than the 52pt of primary/secondary because it
//                typically appears as a trailing destructive link rather than
//                a dominant CTA. Press animation mirrors the other button
//                styles for consistency; reduce-motion wrap is deferred to a
//                later pass.
//

import SwiftUI

/// Destructive action button style.
///
/// Text-only label in `MWColor.again`, 44pt minimum height, full-width. Use
/// for irreversible or dangerous actions. Apply via the `.mwDestructive`
/// static accessor: `Button("Delete deck") { }.buttonStyle(.mwDestructive)`.
public struct MWDestructiveButtonStyle: ButtonStyle {
    /// Creates the destructive button style. Prefer the `.mwDestructive`
    /// accessor at call sites; this initializer is public so the style can
    /// also be constructed explicitly (e.g. for previews or tests).
    public init() {}

    /// Renders the button label with the Modernist destructive treatment: no
    /// fill, no stroke, "again"-tinted text at a 44pt minimum height, and a
    /// brief press scale.
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MWType.bodyL.weight(.semibold))
            .foregroundStyle(MWColor.again)
            .frame(maxWidth: .infinity, minHeight: 44)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(MWMotion.instant, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == MWDestructiveButtonStyle {
    /// Convenience accessor so callers can write `.buttonStyle(.mwDestructive)`.
    static var mwDestructive: MWDestructiveButtonStyle { .init() }
}

#Preview("Destructive button") {
    VStack(spacing: MWSpacing.l) {
        Button("Delete deck") {}.buttonStyle(.mwDestructive)
        Button("Disabled") {}.buttonStyle(.mwDestructive).disabled(true)
    }
    .mwPadding(.all, .xl)
    .background(MWColor.canvas)
}
