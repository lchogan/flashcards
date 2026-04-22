/// SmartStudyView.swift
///
/// Smart (FSRS) study surface. Shows a card face, tap-to-flip to reveal back,
/// then a row of MWRatingButtons with FSRS-computed interval previews.
/// Delegates persistence to SessionEngine.
///
/// Dependencies: SwiftUI, SwiftData, DS, FsrsScheduler, SessionEngine,
/// Clock, AppState.

import SwiftData
import SwiftUI

struct SmartStudyView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    let card: CardEntity
    let sessionId: String
    let onAdvance: () -> Void

    @State private var isFlipped = false
    @State private var previewByRating: [MWRating: Int64] = [:]

    private let scheduler = FsrsScheduler(weights: nil)

    var body: some View {
        VStack(spacing: MWSpacing.l) {
            MWTopBar(title: "Smart Study")
            Spacer()
            cardBody
                .mwCard()
                .mwPadding(.horizontal, .xl)
                .contentShape(Rectangle())
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("mw.session.card")
                .onTapGesture {
                    isFlipped.toggle()
                    updatePreview()
                }
            Spacer()
            if isFlipped {
                HStack(spacing: MWSpacing.s) {
                    ForEach(MWRating.allCases, id: \.self) { rating in
                        MWRatingButton(rating: rating, intervalLabel: label(for: rating)) {
                            rate(rating)
                        }
                    }
                }
                .mwPadding(.horizontal, .l)
            } else {
                Text("Tap card to reveal answer")
                    .font(MWType.body)
                    .foregroundStyle(MWColor.inkMuted)
            }
        }
        .onAppear { updatePreview() }
    }

    @ViewBuilder
    private var cardBody: some View {
        VStack(spacing: MWSpacing.m) {
            Text(isFlipped ? card.backText : card.frontText)
                .font(MWType.headingM)
                .foregroundStyle(MWColor.ink)
                .multilineTextAlignment(.center)
        }
    }

    private func label(for rating: MWRating) -> String {
        guard let milliseconds = previewByRating[rating] else {
            return "—"
        }
        let days = Double(milliseconds) / 86_400_000
        if days < 1 {
            return "\(Int(Double(milliseconds) / 60_000))m"
        }
        return "\(Int(days))d"
    }

    private func updatePreview() {
        previewByRating = scheduler.intervalPreview(for: card.fsrsState(), at: Clock.nowMs())
    }

    private func rate(_ rating: MWRating) {
        let engine = SessionEngine(
            context: context,
            userId: currentUserId(),
            scheduler: scheduler,
            sessionId: sessionId
        )
        try? engine.rate(card: card, rating: rating, at: Clock.nowMs(), mode: .smart)
        isFlipped = false
        onAdvance()
    }

    private func currentUserId() -> String {
        if case .authenticated(let id) = appState.authStatus {
            return id
        }
        return "anonymous"
    }
}
