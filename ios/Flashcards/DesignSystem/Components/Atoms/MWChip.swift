//
//  MWChip.swift
//  Flashcards
//
//  Purpose: Selectable pill-shaped chip used for tag filters, sort options, and
//           other compact toggle surfaces.
//  Dependencies: SwiftUI, MWColor, MWSpacing, MWType, MWRadius, MWBorder.
//  Key concepts: When `selected` is true, background flips to ink and label to
//                paper — the chip becomes the filled companion to MWPill.
//

import SwiftUI

/// Single selectable chip. Stateless — caller owns `selected`.
public struct MWChip: View {
    let text: String
    let selected: Bool
    let onTap: () -> Void

    public init(text: String, selected: Bool = false, onTap: @escaping () -> Void) {
        self.text = text
        self.selected = selected
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(MWType.bodyS.weight(.medium))
                .foregroundStyle(selected ? MWColor.paper : MWColor.ink)
                .mwPadding(.horizontal, .m)
                .mwPadding(.vertical, .xs)
                .background(selected ? MWColor.ink : MWColor.paper)
                .mwCornerRadius(.l)
                .mwStroke(color: MWColor.ink, width: MWBorder.defaultWidth, cornerRadius: MWRadius.l)
        }
        .buttonStyle(.plain)
    }
}

#Preview("MWChip") {
    HStack(spacing: MWSpacing.s) {
        MWChip(text: "All", selected: true) {}
        MWChip(text: "Due") {}
        MWChip(text: "New") {}
    }
    .mwPadding(.all, .l)
    .background(MWColor.canvas)
}
