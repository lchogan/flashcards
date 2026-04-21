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
//                site propagates everywhere. Calling `.mwStroke()` with no
//                arguments intentionally relies on its ink / 1.5pt defaults.
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
            .mwStroke()
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
