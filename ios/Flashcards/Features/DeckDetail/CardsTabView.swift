/// CardsTabView.swift
///
/// Scrolling list of cards with optional multi-select mode for bulk ops. Tap
/// opens CardEditView; long-press enters select mode; selected cards are
/// actionable via BulkActionsSheet (delete, reset progress).
///
/// Dependencies: SwiftUI, SwiftData, DeckDetailViewModel, CardRepository,
/// MWCardTile, MWDot, CardEditView, BulkActionsSheet, Clock.

import SwiftData
import SwiftUI

struct CardsTabView: View {
    @Bindable var viewModel: DeckDetailViewModel

    @State private var editingCard: CardEntity?
    @State private var inSelectMode = false
    @State private var selected = Set<String>()
    @State private var showingBulk = false

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: MWSpacing.s) {
                    ForEach(viewModel.cards, id: \.id) { card in
                        MWCardTile(
                            frontText: card.frontText,
                            backTextPreview: card.backText,
                            dueLabel: dueLabel(for: card)
                        )
                        .overlay(alignment: .topTrailing) {
                            if inSelectMode {
                                MWDot(color: selected.contains(card.id) ? MWColor.ink : MWColor.inkFaint)
                                    .mwPadding(.all, .s)
                            }
                        }
                        .onTapGesture { handleTap(card: card) }
                        .onLongPressGesture {
                            inSelectMode = true
                            selected.insert(card.id)
                        }
                    }
                }
                .mwPadding(.horizontal, .l)
            }
            if inSelectMode {
                selectBar
            }
        }
        .sheet(isPresented: $showingBulk) {
            BulkActionsSheet(
                cardIds: Array(selected),
                onDelete: {
                    bulkDelete()
                    exitSelectMode()
                },
                onReset: {
                    bulkReset()
                    exitSelectMode()
                }
            )
        }
        .sheet(item: $editingCard) { card in
            CardEditView(card: card)
        }
    }

    @ViewBuilder
    private var selectBar: some View {
        HStack {
            Button("Cancel") { exitSelectMode() }
            Spacer()
            Button("\(selected.count) selected • Bulk actions") {
                showingBulk = true
            }
            .disabled(selected.isEmpty)
        }
        .mwPadding(.all, .m)
        .background(MWColor.paper.ignoresSafeArea(edges: .bottom))
        .mwStroke(color: MWColor.ink, width: MWBorder.defaultWidth)
    }

    private func handleTap(card: CardEntity) {
        if inSelectMode {
            if selected.contains(card.id) {
                selected.remove(card.id)
            } else {
                selected.insert(card.id)
            }
        } else {
            editingCard = card
        }
    }

    private func exitSelectMode() {
        inSelectMode = false
        selected.removeAll()
        showingBulk = false
    }

    private func bulkDelete() {
        let repo = CardRepository(context: viewModel.context)
        for id in selected {
            if let card = viewModel.cards.first(where: { $0.id == id }) {
                try? repo.softDelete(card)
            }
        }
        try? viewModel.load()
    }

    private func bulkReset() {
        let repo = CardRepository(context: viewModel.context)
        for id in selected {
            if let card = viewModel.cards.first(where: { $0.id == id }) {
                try? repo.resetProgress(card)
            }
        }
        try? viewModel.load()
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
