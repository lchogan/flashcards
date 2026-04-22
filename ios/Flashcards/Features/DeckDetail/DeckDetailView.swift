/// DeckDetailView.swift
///
/// Tab host for a deck: Cards + History. Hosts the Study launcher and Create
/// Card sheet. Loads state via DeckDetailViewModel.
///
/// Dependencies: SwiftUI, SwiftData, DS Atoms/Molecules, DeckDetailViewModel,
/// CardsTabView, HistoryTabView, CreateCardView, SessionRootView.

import SwiftData
import SwiftUI

struct DeckDetailView: View {
    enum Tab: String, CaseIterable { case history = "History", cards = "Cards" }

    @Environment(\.modelContext) private var context
    @State private var viewModel: DeckDetailViewModel?
    @State private var tab: Tab = .cards
    @State private var showingCreateCard = false
    @State private var showingStudy = false

    let deckId: String

    var body: some View {
        MWScreen {
            VStack(spacing: MWSpacing.l) {
                if let viewModel, let deck = viewModel.deck {
                    header(deck: deck, viewModel: viewModel)

                    HStack(spacing: MWSpacing.s) {
                        ForEach(Tab.allCases, id: \.self) { candidate in
                            MWChip(text: candidate.rawValue, selected: tab == candidate) {
                                tab = candidate
                            }
                        }
                        Spacer()
                    }
                    .mwPadding(.horizontal, .l)

                    switch tab {
                    case .cards:    CardsTabView(viewModel: viewModel)
                    case .history:  HistoryTabView(viewModel: viewModel)
                    }

                    HStack {
                        MWButton("Study now") { showingStudy = true }
                            .disabled(viewModel.cards.isEmpty)
                    }
                    .mwPadding(.all, .l)
                } else {
                    ProgressView().task {
                        if viewModel == nil {
                            viewModel = DeckDetailViewModel(context: context, deckId: deckId)
                        }
                        try? viewModel?.load()
                    }
                }
            }
        }
        .mwScreenChrome()
        .fullScreenCover(isPresented: $showingStudy) {
            SessionRootView(deckId: deckId, onDismiss: {
                showingStudy = false
                try? viewModel?.load()
            })
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreateCard = true
                } label: { MWIcon(.add) }
            }
        }
        .sheet(isPresented: $showingCreateCard) {
            CreateCardView(deckId: deckId, onSaved: { try? viewModel?.load() })
        }
    }

    @ViewBuilder
    private func header(deck: DeckEntity, viewModel: DeckDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: MWSpacing.s) {
            MWEyebrow(MWAccent(rawValue: deck.accentColor)?.rawValue.uppercased() ?? "")
            Text(deck.title).font(MWType.headingL).foregroundStyle(MWColor.ink)
            HStack {
                MWDuePill(count: viewModel.dueCount)
                Spacer()
            }
        }
        .mwPadding(.horizontal, .l)
    }
}
