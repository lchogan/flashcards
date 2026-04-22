/// HistoryTabView.swift
///
/// Shows up to 20 most-recent sessions for the deck. Each row surfaces mode,
/// cards reviewed, accuracy, and a relative "x ago" timestamp.
///
/// Dependencies: SwiftUI, DeckDetailViewModel.

import SwiftUI

struct HistoryTabView: View {
    let viewModel: DeckDetailViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: MWSpacing.s) {
                if viewModel.recentSessions.isEmpty {
                    MWEmptyState(
                        title: "No sessions yet",
                        message: "Study this deck and recent sessions will show here."
                    )
                } else {
                    ForEach(viewModel.recentSessions, id: \.id) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: MWSpacing.xs) {
                                Text(session.mode.capitalized)
                                    .font(MWType.bodyL.weight(.semibold))
                                    .foregroundStyle(MWColor.ink)
                                Text("\(session.cardsReviewed) cards • \(Int(session.accuracyPct * 100))%")
                                    .font(MWType.bodyS)
                                    .foregroundStyle(MWColor.inkMuted)
                            }
                            Spacer()
                            Text(relative(session.startedAtMs))
                                .font(MWType.bodyS)
                                .foregroundStyle(MWColor.inkFaint)
                        }
                        .mwPadding(.all, .m)
                        .background(MWColor.paper)
                        .mwCornerRadius(.s)
                        .mwStroke(color: MWColor.ink, width: MWBorder.defaultWidth, cornerRadius: MWRadius.s)
                    }
                }
            }
            .mwPadding(.horizontal, .l)
        }
    }

    private func relative(_ milliseconds: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(milliseconds) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
