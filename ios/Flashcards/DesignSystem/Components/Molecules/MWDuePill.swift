//
//  MWDuePill.swift
//  Flashcards
//
//  Purpose: Inline pill surfacing the "N due" count for a deck on HomeView.
//  Dependencies: SwiftUI, MWColor, MWSpacing, MWType, MWRadius, MWBorder, MWDot.
//  Key concepts: The dot tint flips to the grey `inkFaint` when count is zero,
//                so the whole HStack reads "All caught up" without re-plumbing.
//

import SwiftUI

/// Deck due-count indicator pill.
public struct MWDuePill: View {
    let dueCount: Int

    /// Creates a new instance.
    public init(count: Int) { self.dueCount = count }

    /// View body.
    public var body: some View {
        HStack(spacing: MWSpacing.xs) {
            MWDot(color: dueCount >= 1 ? MWColor.good : MWColor.inkFaint)
            Text(dueCount < 1 ? "All caught up" : "\(dueCount) due")
                .font(MWType.bodyS.weight(.semibold))
                .foregroundStyle(MWColor.ink)
        }
        .mwPadding(.horizontal, .s)
        .mwPadding(.vertical, .xs)
        .background(MWColor.paper)
        .mwCornerRadius(.l)
        .mwStroke(color: MWColor.ink, width: MWBorder.defaultWidth, cornerRadius: MWRadius.l)
    }
}

#Preview("MWDuePill") {
    VStack(spacing: MWSpacing.m) {
        MWDuePill(count: 0)
        MWDuePill(count: 12)
    }
    .mwPadding(.all, .l)
    .background(MWColor.canvas)
}
