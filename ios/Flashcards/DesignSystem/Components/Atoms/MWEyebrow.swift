//
//  MWEyebrow.swift
//  Flashcards
//
//  Purpose: Standalone eyebrow-label atom. Renders short uppercase text in
//           `MWType.eyebrow` with tracking and muted ink — the pattern used
//           above section headers, form fields, and metadata groups.
//  Dependencies: SwiftUI (View, Text), `MWColor`, `MWType`.
//  Key concepts: Input text is uppercased at render time, so call sites can
//                pass naturally cased strings. `MWTextField` inlines this same
//                treatment for its field label; extracting it here lets future
//                atoms (`MWSectionHeader`, list group captions) share the
//                exact typography without duplicating the recipe.
//

import SwiftUI

/// Uppercase eyebrow label rendered in `MWType.eyebrow` with tracked, muted ink.
public struct MWEyebrow: View {
    let text: String

    /// Creates an eyebrow label. The input string is uppercased on render.
    /// - Parameter text: Label text in any casing; it will be uppercased.
    public init(_ text: String) { self.text = text }

    /// Renders the uppercased text with eyebrow tracking and `MWColor.inkMuted`.
    public var body: some View {
        Text(text.uppercased())
            .font(MWType.eyebrow).tracking(MWType.eyebrowTracking)
            .foregroundStyle(MWColor.inkMuted)
    }
}

#Preview("MWEyebrow") {
    MWEyebrow("Overview")
        .mwPadding(.all, .l)
        .background(MWColor.canvas)
}
