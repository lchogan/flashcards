//
//  Shadows.swift
//  Flashcards
//
//  Purpose: Shadow tokens. The Modernist language uses borders rather than
//           shadows, so the only sanctioned shadow is the stacked-paper deck
//           effect.
//  Dependencies: SwiftUI (View), `MWColor`.
//  Key concepts: If you find yourself reaching for a shadow outside the deck
//                metaphor, stop and use a border instead.
//

import SwiftUI

/// Modernist uses borders, not shadows. The single exception is the stacked-paper deck metaphor.
public enum MWShadow {
    /// Subtle shadow for the stacked-paper deck metaphor used by card stacks.
    public static func deck(_ content: some View) -> some View {
        content.shadow(color: MWColor.ink.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}
