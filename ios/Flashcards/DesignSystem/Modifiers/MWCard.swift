//
//  MWCard.swift
//  Flashcards
//
//  Purpose: `MWCardStyle` view modifier and the `mwCard()` helper that compose
//           the Modernist paper-surface card: ink-bordered, flat, no shadow.
//  Dependencies: SwiftUI, `MWColor`, `MWSpacingToken` via `mwPadding`,
//                `MWRadiusToken` via `mwCornerRadius`, and `mwStroke` which
//                defaults to `MWColor.ink` at `MWBorder.defaultWidth`.
//  Key concepts: The card is a composition of design-system tokens rather than
//                raw SwiftUI values — padding, corner radius, and border width
//                all route through the token layer so one change at the token
//                site propagates everywhere. `.mwStroke(cornerRadius:)` is
//                passed `MWRadius.m` to match the `.mwCornerRadius(.m)` applied
//                just above it, so the ink border traces the rounded clip
//                instead of drawing a sharp rectangle that the clip then eats
//                into at each corner.
//

import SwiftUI

/// Paper-style card surface with 1.5pt ink border.
///
/// Applies large padding, paper background, medium corner radius, and the
/// design-system default stroke (ink at 1.5pt). No shadow: the Modernist
/// language is border-first, shadow-averse.
public struct MWCardStyle: ViewModifier {
    /// Wraps `content` in the Modernist card surface.
    public func body(content: Content) -> some View {
        content
            .mwPadding(.all, .l)
            .background(MWColor.paper)
            .mwCornerRadius(.m)
            .mwStroke(cornerRadius: MWRadius.m)
    }
}

public extension View {
    /// Applies the Modernist paper-card surface to the view.
    func mwCard() -> some View { modifier(MWCardStyle()) }
}

#Preview("MWCard") {
    MWScreen {
        Text("Sample card content").font(MWType.bodyL).foregroundStyle(MWColor.ink).mwCard()
    }
}
