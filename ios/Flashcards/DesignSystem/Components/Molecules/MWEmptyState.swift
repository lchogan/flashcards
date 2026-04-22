//
//  MWEmptyState.swift
//  Flashcards
//
//  Purpose: Centered empty-state placeholder with optional eyebrow, headline,
//           body copy, and CTA. Replaces bespoke "nothing here" layouts.
//  Dependencies: SwiftUI, MWColor, MWSpacing, MWType, MWButton, MWEyebrow.
//

import SwiftUI

/// Centered empty-state block. Each slot (eyebrow / message / cta) is optional.
public struct MWEmptyState: View {
    let eyebrow: String?
    let title: String
    let message: String?
    let ctaTitle: String?
    let onCtaTap: (() -> Void)?

    /// Creates a new instance.
    public init(
        eyebrow: String? = nil,
        title: String,
        message: String? = nil,
        ctaTitle: String? = nil,
        onCtaTap: (() -> Void)? = nil
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.message = message
        self.ctaTitle = ctaTitle
        self.onCtaTap = onCtaTap
    }

    /// View body.
    public var body: some View {
        VStack(spacing: MWSpacing.l) {
            if let eyebrow { MWEyebrow(eyebrow) }
            Text(title)
                .font(MWType.headingM)
                .foregroundStyle(MWColor.ink)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(MWType.body)
                    .foregroundStyle(MWColor.inkMuted)
                    .multilineTextAlignment(.center)
            }
            if let ctaTitle, let onCtaTap {
                MWButton(ctaTitle, action: onCtaTap)
            }
        }
        .mwPadding(.all, .xl)
    }
}

#Preview("MWEmptyState") {
    MWEmptyState(
        eyebrow: "No decks",
        title: "Nothing here yet",
        message: "Create your first deck to start studying.",
        ctaTitle: "Create deck",
        onCtaTap: {}
    )
    .background(MWColor.canvas)
}
