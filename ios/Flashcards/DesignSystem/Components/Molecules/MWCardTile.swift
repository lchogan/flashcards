//
//  MWCardTile.swift
//  Flashcards
//
//  Purpose: Row/tile used in deck detail lists to show a single card's front,
//           optional back preview, assigned sub-topics, and due label.
//  Dependencies: SwiftUI, MWColor, MWSpacing, MWType, MWRadius, MWBorder, MWPill.
//

import SwiftUI

/// Card list row tile. Front text is the emphasised line; back preview, sub-topic
/// pills, and due label render below as supporting metadata.
public struct MWCardTile: View {
    let frontText: String
    let backTextPreview: String?
    let subTopics: [String]
    let dueLabel: String?

    /// Creates a new instance.
    public init(
        frontText: String,
        backTextPreview: String? = nil,
        subTopics: [String] = [],
        dueLabel: String? = nil
    ) {
        self.frontText = frontText
        self.backTextPreview = backTextPreview
        self.subTopics = subTopics
        self.dueLabel = dueLabel
    }

    /// View body.
    public var body: some View {
        VStack(alignment: .leading, spacing: MWSpacing.s) {
            Text(frontText)
                .font(MWType.bodyL.weight(.semibold))
                .foregroundStyle(MWColor.ink)
                .lineLimit(2)
            if let backTextPreview {
                Text(backTextPreview)
                    .font(MWType.body)
                    .foregroundStyle(MWColor.inkMuted)
                    .lineLimit(2)
            }
            HStack(spacing: MWSpacing.xs) {
                ForEach(subTopics, id: \.self) { topic in
                    MWPill(topic, tint: MWColor.inkMuted)
                }
                Spacer()
                if let dueLabel {
                    Text(dueLabel)
                        .font(MWType.bodyS)
                        .foregroundStyle(MWColor.inkMuted)
                }
            }
        }
        .mwPadding(.all, .m)
        .background(MWColor.paper)
        .mwCornerRadius(.s)
        .mwStroke(color: MWColor.ink, width: MWBorder.defaultWidth, cornerRadius: MWRadius.s)
    }
}

#Preview("MWCardTile") {
    MWCardTile(
        frontText: "What is a retain cycle?",
        backTextPreview: "Two objects holding strong refs to each other so ARC can't free them.",
        subTopics: ["Memory", "ARC"],
        dueLabel: "Due in 3d"
    )
    .mwPadding(.all, .l)
    .background(MWColor.canvas)
}
