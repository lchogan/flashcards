/// SessionSummaryView.swift
///
/// Closing screen for a study session: cards reviewed, accuracy, and a Done
/// CTA that dismisses the session cover.
///
/// Dependencies: SwiftUI, SessionEntity, DS Atoms/Molecules.

import SwiftUI

struct SessionSummaryView: View {
    let session: SessionEntity
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: MWSpacing.l) {
            Spacer()
            MWEyebrow("Session summary")
            Text("\(session.cardsReviewed) cards reviewed")
                .font(MWType.headingL)
                .foregroundStyle(MWColor.ink)
            Text(String(format: "%.0f%% accuracy", session.accuracyPct))
                .font(MWType.bodyL)
                .foregroundStyle(MWColor.inkMuted)
            Spacer()
            MWButton("Done", action: onDismiss)
                .mwPadding(.horizontal, .xl)
        }
        .mwPadding(.all, .l)
    }
}
