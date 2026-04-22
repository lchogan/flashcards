//
//  MWButtonPress.swift
//  Flashcards
//
//  Purpose: Shared press-scale + animation modifier used by every Modernist
//           button style. Collapses the duplicated scale/animation pair from
//           MWPrimaryButtonStyle / MWSecondaryButtonStyle / MWDestructiveButtonStyle
//           into a single call site with reduce-motion compliance baked in.
//  Dependencies: SwiftUI (View), MWMotion (respecting reduce-motion), MWColor
//                (none directly). Reads `@Environment(\.accessibilityReduceMotion)`.
//  Key concepts: The 0.98 press-scale constant is a button-feedback primitive.
//                Calling `.animation(MWMotion.instant, ...)` directly violates
//                Motion.swift's "always wrap in respecting(_:reduceMotion:)"
//                contract; this modifier is the canonical safe form.
//

import SwiftUI

/// Applies the Modernist button press-scale animation, honoring Reduce Motion.
public struct MWButtonPress: ViewModifier {
    /// 0.98 is a subtle but perceptible press feedback without making the label shift visibly.
    private static let pressedScale: CGFloat = 0.98

    /// Whether the button is currently pressed (passed from `configuration.isPressed`).
    let isPressed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? Self.pressedScale : 1.0)
            .animation(
                MWMotion.respecting(MWMotion.instant, reduceMotion: reduceMotion),
                value: isPressed
            )
    }
}

public extension View {
    /// Applies the standard Modernist button press-scale + reduce-motion-safe animation.
    /// Pass `configuration.isPressed` from a `ButtonStyle` body.
    func mwButtonPress(isPressed: Bool) -> some View {
        modifier(MWButtonPress(isPressed: isPressed))
    }
}
