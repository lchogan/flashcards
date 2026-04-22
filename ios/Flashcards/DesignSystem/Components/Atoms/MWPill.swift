//
//  MWPill.swift
//  Flashcards
//
//  Purpose: Small rounded tag atom used to label metadata (counts, statuses,
//           categories). Renders short text in a tinted, semi-transparent
//           capsule using the design-system tokens.
//  Dependencies: SwiftUI (View, Text), `MWColor`, `MWType`, `MWSpacingToken`
//                via `mwPadding`, `MWRadiusToken` via `mwCornerRadius`.
//  Key concepts: Background tint is derived from the foreground `tint` at a
//                fixed 8% opacity — this keeps the pill visually coherent with
//                any ink colour. The 0.08 alpha is a plan-authorised raw
//                literal; if many atoms come to share this value, a follow-up
//                task can centralise a `MWColor.tintFillAlpha` token.
//

import SwiftUI

/// Compact rounded tag rendering `text` in a tinted capsule.
/// Use for metadata labels (deck counts, status chips, categories). For
/// interactive tags see future `MWChip` atoms.
public struct MWPill: View {
    let text: String
    let tint: Color

    /// Creates a pill with the given label and tint colour.
    /// - Parameters:
    ///   - text: Short label text. Kept to one or two words in practice.
    ///   - tint: Foreground colour; the background is derived as `tint` at 8%
    ///     opacity. Defaults to `MWColor.ink`.
    public init(_ text: String, tint: Color = MWColor.ink) {
        self.text = text
        self.tint = tint
    }

    /// Renders the label in `MWType.bodyS` semibold on a tinted rounded background.
    public var body: some View {
        Text(text)
            .font(MWType.bodyS.weight(.semibold))
            .foregroundStyle(tint)
            .mwPadding(.horizontal, .s)
            .mwPadding(.vertical, .xs)
            .background(tint.opacity(0.08))
            .mwCornerRadius(.l)
    }
}

#Preview("MWPill") {
    MWPill("New")
        .mwPadding(.all, .l)
        .background(MWColor.canvas)
}
