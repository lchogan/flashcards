//
//  MWPrimaryButtonStyle.swift
//  Flashcards
//
//  Purpose: Primary call-to-action button style — the solid ink pill used for
//           the one dominant action on a screen (e.g. "Continue with Apple",
//           "Save deck"). Only one primary button should appear per screen.
//  Dependencies: SwiftUI (ButtonStyle, Environment), `MWType`, `MWColor`,
//                `MWSpacingToken` via `mwPadding`, `MWRadiusToken` via
//                `mwCornerRadius`, and `MWMotion`.
//  Key concepts: Flat, border-first Modernist surface — no shadow, no gradient.
//                Disabled state swaps `MWColor.ink` for `MWColor.inkFaint`
//                rather than reducing opacity, so the control remains
//                legible against `MWColor.canvas`. The press animation is a
//                short 0.98-scale tween via `MWMotion.instant`; the
//                reduce-motion wrap around it is intentionally deferred to a
//                later designer-sign-off pass so every button style can adopt
//                it consistently.
//

import SwiftUI

/// Primary call-to-action button style.
///
/// Fills available width, 52pt tall, ink-filled paper-text pill. Use at most
/// one per screen. Apply via the `.mwPrimary` static accessor:
/// `Button("Continue") { }.buttonStyle(.mwPrimary)`.
public struct MWPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    /// Creates the primary button style. Prefer the `.mwPrimary` accessor
    /// at call sites; this initializer is public so the style can also be
    /// constructed explicitly (e.g. for previews or tests).
    public init() {}

    /// Renders the button label with the Modernist primary surface: ink fill,
    /// paper foreground, medium corner radius, and a brief press scale.
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MWType.bodyL.weight(.semibold))
            .foregroundStyle(MWColor.paper)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isEnabled ? MWColor.ink : MWColor.inkFaint)
            .mwCornerRadius(.s)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(MWMotion.instant, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == MWPrimaryButtonStyle {
    /// Convenience accessor so callers can write `.buttonStyle(.mwPrimary)`.
    static var mwPrimary: MWPrimaryButtonStyle { .init() }
}

#Preview("Primary button") {
    VStack(spacing: MWSpacing.l) {
        Button("Continue with Apple") {}.buttonStyle(.mwPrimary)
        Button("Disabled") {}.buttonStyle(.mwPrimary).disabled(true)
    }
    .mwPadding(.all, .xl)
    .background(MWColor.canvas)
}
