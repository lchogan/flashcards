/// SearchView.swift
///
/// Client-side LIKE search over decks (title) and cards (front/back). Runs on
/// keystroke once the query has 2+ characters.
///
/// Dependencies: SwiftUI, SwiftData, DS Atoms/Molecules, DeckEntity, CardEntity.

import SwiftData
import SwiftUI

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var deckResults: [DeckEntity] = []
    @State private var cardResults: [CardEntity] = []

    var body: some View {
        NavigationStack {
            MWScreen {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    MWTextField(label: "Search", text: $query)
                        .onChange(of: query) { _, newValue in runSearch(newValue) }
                    if !deckResults.isEmpty {
                        MWSection("Decks") {
                            ForEach(deckResults, id: \.id) { deck in
                                Text(deck.title)
                                    .font(MWType.bodyL)
                                    .foregroundStyle(MWColor.ink)
                            }
                        }
                    }
                    if !cardResults.isEmpty {
                        MWSection("Cards") {
                            ForEach(cardResults, id: \.id) { card in
                                MWCardTile(
                                    frontText: card.frontText,
                                    backTextPreview: card.backText
                                )
                            }
                        }
                    }
                    if query.count >= 2, deckResults.isEmpty, cardResults.isEmpty {
                        Text("No matches.")
                            .font(MWType.body)
                            .foregroundStyle(MWColor.inkMuted)
                    }
                }
                .mwPadding(.all, .xl)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
        }
    }

    private func runSearch(_ rawQuery: String) {
        guard rawQuery.trimmingCharacters(in: .whitespaces).count >= 2 else {
            deckResults = []
            cardResults = []
            return
        }
        let needle = rawQuery.lowercased()
        deckResults =
            (try? context.fetch(
                FetchDescriptor<DeckEntity>(
                    predicate: #Predicate { $0.syncDeletedAtMs == nil }
                )))?.filter { $0.title.lowercased().contains(needle) } ?? []
        cardResults =
            (try? context.fetch(
                FetchDescriptor<CardEntity>(
                    predicate: #Predicate { $0.syncDeletedAtMs == nil }
                )))?.filter {
                $0.frontText.lowercased().contains(needle) || $0.backText.lowercased().contains(needle)
            } ?? []
    }
}
