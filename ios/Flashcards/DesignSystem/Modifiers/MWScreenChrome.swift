//
//  MWScreenChrome.swift
//  Flashcards
//
//  Purpose: Standard top-bar chrome reservation + canvas background applied to
//           every top-level `NavigationStack` destination. Guarantees a
//           consistent visible navigation bar tinted to the Modernist canvas
//           token so screens never blend into the system default or flash
//           translucent material on scroll.
//  Dependencies: SwiftUI (`ViewModifier`, `toolbarBackground`, `toolbarColorScheme`),
//                `MWColor.canvas` for the bar and page background.
//  Key concepts: The toolbar APIs are declarative reservations — stacking
//                `.toolbarBackground(MWColor.canvas, for: .navigationBar)` with
//                `.toolbarBackground(.visible, for: .navigationBar)` pins the
//                bar tint so it does not disappear at the top of the scroll
//                edge. `.toolbarColorScheme(nil, ...)` keeps the system
//                responsible for choosing light/dark content, honoring the
//                user's appearance setting instead of forcing either mode.
//

import SwiftUI

/// Applies the standard top-bar chrome reservation and canvas background
/// used by all top-level NavigationStack destinations.
public struct MWScreenChrome: ViewModifier {
    /// Pins a visible, canvas-tinted navigation bar and paints the page
    /// background with the same canvas token so the bar edge disappears
    /// into the surface it sits on.
    public func body(content: Content) -> some View {
        content
            .toolbarBackground(MWColor.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(nil, for: .navigationBar)
            .background(MWColor.canvas)
    }
}

public extension View {
    /// Applies the Modernist top-bar chrome reservation and canvas background.
    func mwScreenChrome() -> some View { modifier(MWScreenChrome()) }
}
