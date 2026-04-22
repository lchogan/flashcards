//
//  MWSecondaryButtonStyle.swift
//  Flashcards
//
//  Purpose: Secondary button style — a paper-filled, ink-bordered pill used for
//           supporting actions alongside a primary button (e.g. "Cancel",
//           "Learn more"). The Modernist inverse of `MWPrimaryButtonStyle`:
//           same footprint, outline instead of solid fill.
//  Dependencies: SwiftUI (ButtonStyle, Environment), `MWType`, `MWColor`,
//                `MWRadiusToken` via `mwCornerRadius`, `mwStroke` (+ its
//                defaults `MWColor.ink` / `MWBorder.defaultWidth`),
//                `MWControl.Height`, and `MWButtonPress`.
//  Key concepts: Border-first surface on paper — no shadow, no gradient. The
//                stroke passes `cornerRadius: MWRadius.s` so the overlay traces
//                the rounded clip applied by `mwCornerRadius(.s)`; without it
//                the border would draw as a sharp rectangle over a rounded
//                fill (see Task 0.22-fix, commit 164dd80). Disabled state
//                applies a 0.5 opacity to the whole body rather than swapping
//                colors, because the outline + paper combination reads
//                legibly enough when faded. Height comes from
//                `MWControl.Height.primary`; the press animation is delegated
//                to `.mwButtonPress(isPressed:)` which honors Reduce Motion
//                via `MWMotion.respecting`.
//

import SwiftUI

/// Secondary button style.
///
/// Fills available width, 52pt tall, paper-filled pill with an ink outline.
/// Pair with an `MWPrimaryButtonStyle` button for the dominant action, or use
/// standalone for less-emphasized actions. Apply via the `.mwSecondary` static
/// accessor: `Button("Cancel") { }.buttonStyle(.mwSecondary)`.
public struct MWSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    /// Creates the secondary button style. Prefer the `.mwSecondary` accessor
    /// at call sites; this initializer is public so the style can also be
    /// constructed explicitly (e.g. for previews or tests).
    public init() {}

    /// Renders the button label with the Modernist secondary surface: paper
    /// fill, ink foreground, medium corner radius with matching ink stroke,
    /// and a brief press scale.
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MWType.bodyL.weight(.semibold))
            .foregroundStyle(MWColor.ink)
            .frame(maxWidth: .infinity, minHeight: MWControl.Height.primary)
            .background(MWColor.paper)
            .mwCornerRadius(.s)
            .mwStroke(cornerRadius: MWRadius.s)
            .opacity(isEnabled ? 1.0 : 0.5)
            .mwButtonPress(isPressed: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == MWSecondaryButtonStyle {
    /// Convenience accessor so callers can write `.buttonStyle(.mwSecondary)`.
    static var mwSecondary: MWSecondaryButtonStyle { .init() }
}

#Preview("Secondary button") {
    VStack(spacing: MWSpacing.l) {
        Button("Cancel") {}.buttonStyle(.mwSecondary)
        Button("Disabled") {}.buttonStyle(.mwSecondary).disabled(true)
    }
    .mwPadding(.all, .xl)
    .background(MWColor.canvas)
}
