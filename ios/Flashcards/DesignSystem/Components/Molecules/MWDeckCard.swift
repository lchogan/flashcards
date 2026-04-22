//
//  MWDeckCard.swift
//  Flashcards
//
//  Purpose: Deck summary card shown in the HomeView grid. Surfaces title,
//           due count, card count, and sub-topic count inside a stacked-paper
//           backdrop with the deck's accent tint in the top-left corner.
//  Dependencies: SwiftUI, MWColor, MWSpacing, MWType, MWAccent, MWDuePill,
//                MWStackedDeckPaper.
//

import SwiftUI

/// Deck summary card — stacked paper + accent swatch + counts.
public struct MWDeckCard: View {
    let title: String
    let subTopicCount: Int
    let cardCount: Int
    let dueCount: Int
    let accent: MWAccent

    /// Creates a new instance.
    public init(title: String, subTopicCount: Int, cardCount: Int, dueCount: Int, accent: MWAccent) {
        self.title = title
        self.subTopicCount = subTopicCount
        self.cardCount = cardCount
        self.dueCount = dueCount
        self.accent = accent
    }

    /// View body.
    public var body: some View {
        MWStackedDeckPaper {
            VStack(alignment: .leading, spacing: MWSpacing.m) {
                HStack {
                    Rectangle().fill(accent.color).frame(width: 10, height: 10)
                    Spacer()
                    MWDuePill(count: dueCount)
                }
                Text(title)
                    .font(MWType.headingM)
                    .foregroundStyle(MWColor.ink)
                    .lineLimit(2)
                HStack(spacing: MWSpacing.l) {
                    Label("\(cardCount)", systemImage: "square.stack.3d.up")
                        .font(MWType.bodyS).foregroundStyle(MWColor.inkMuted)
                    Label("\(subTopicCount)", systemImage: "tag")
                        .font(MWType.bodyS).foregroundStyle(MWColor.inkMuted)
                }
            }
            .mwPadding(.all, .l)
        }
        .mwAccent(accent.color)
        .frame(height: 160)
    }
}

#Preview("MWDeckCard") {
    MWDeckCard(
        title: "Swift patterns & idioms",
        subTopicCount: 4,
        cardCount: 82,
        dueCount: 7,
        accent: .moss
    )
    .mwPadding(.all, .l)
    .background(MWColor.canvas)
}
