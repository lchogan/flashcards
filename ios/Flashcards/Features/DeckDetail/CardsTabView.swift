/// CardsTabView.swift
///
/// Scrolling list of cards in a deck, each rendered as MWCardTile. Tapping a
/// tile opens CardEditView.
///
/// Dependencies: SwiftUI, DeckDetailViewModel, MWCardTile, CardEditView, Clock.

import SwiftUI

struct CardsTabView: View {
    @Bindable var viewModel: DeckDetailViewModel
    @State private var editingCard: CardEntity?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: MWSpacing.s) {
                ForEach(viewModel.cards, id: \.id) { card in
                    Button {
                        editingCard = card
                    } label: {
                        MWCardTile(
                            frontText: card.frontText,
                            backTextPreview: card.backText,
                            dueLabel: dueLabel(for: card)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .mwPadding(.horizontal, .l)
        }
        .sheet(item: $editingCard) { card in
            CardEditView(card: card)
        }
    }

    private func dueLabel(for card: CardEntity) -> String? {
        guard let due = card.dueAtMs else {
            return card.state == "new" ? "New" : nil
        }
        let days = Int((Double(due - Clock.nowMs()) / 86_400_000).rounded())
        if days <= 0 {
            return "Due"
        }
        return "\(days)d"
    }
}
