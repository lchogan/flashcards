/// BasicStudyView.swift
///
/// Basic (non-FSRS) study surface. Two-button UX: "Got it" (good) or "Skip"
/// (hard). Reviews are recorded but FSRS state is NOT mutated — SessionEngine
/// handles that via `mode: .basic`.
///
/// Dependencies: SwiftUI, SwiftData, DS, SessionEngine, FsrsScheduler, Clock,
/// AppState.

import SwiftData
import SwiftUI

struct BasicStudyView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    let card: CardEntity
    let sessionId: String
    let onNext: () -> Void

    @State private var isFlipped = false

    var body: some View {
        VStack(spacing: MWSpacing.l) {
            MWTopBar(title: "Basic Study")
            Spacer()
            VStack(spacing: MWSpacing.m) {
                Text(isFlipped ? card.backText : card.frontText)
                    .font(MWType.headingM)
                    .foregroundStyle(MWColor.ink)
                    .multilineTextAlignment(.center)
            }
            .mwCard()
            .mwPadding(.horizontal, .xl)
            .onTapGesture { isFlipped.toggle() }
            Spacer()
            HStack(spacing: MWSpacing.s) {
                MWButton("Got it", kind: .secondary) {
                    record(.good)
                    next()
                }
                MWButton("Skip") {
                    record(.hard)
                    next()
                }
            }
            .mwPadding(.horizontal, .l)
        }
    }

    private func record(_ rating: MWRating) {
        let engine = SessionEngine(
            context: context,
            userId: currentUserId(),
            scheduler: FsrsScheduler(weights: nil),
            sessionId: sessionId
        )
        try? engine.rate(card: card, rating: rating, at: Clock.nowMs(), mode: .basic)
    }

    private func next() {
        isFlipped = false
        onNext()
    }

    private func currentUserId() -> String {
        if case .authenticated(let id) = appState.authStatus {
            return id
        }
        return "anonymous"
    }
}
