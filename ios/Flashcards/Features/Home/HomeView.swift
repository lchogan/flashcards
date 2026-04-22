/// HomeView.swift
///
/// Top-level deck grid screen. Pulls decks + per-deck due counts from
/// HomeViewModel, surfaces CreateDeckView via a bottom sheet, and navigates to
/// DeckDetailView on tap.
///
/// Dependencies: SwiftUI, SwiftData, DS Atoms/Molecules, HomeViewModel,
/// DeckDetailView, CreateDeckView, SearchView.

import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var viewModel: HomeViewModel?
    @State private var showingCreate = false
    @State private var showingSearch = false

    private let userId: String

    init(userId: String) { self.userId = userId }

    var body: some View {
        MWScreen {
            VStack(alignment: .leading, spacing: MWSpacing.l) {
                MWTopBar(
                    title: "Decks",
                    leading: {
                        Button {
                            showingSearch = true
                        } label: { MWIcon(.search) }
                    },
                    trailing: {
                        Button {
                            showingCreate = true
                        } label: { MWIcon(.add) }
                    }
                )

                if let viewModel {
                    if viewModel.decks.isEmpty {
                        MWEmptyState(
                            eyebrow: "No decks yet",
                            title: "Create your first deck.",
                            message: "A deck is a collection of cards on one topic.",
                            ctaTitle: "New deck",
                            onCtaTap: { showingCreate = true }
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                spacing: MWSpacing.m
                            ) {
                                ForEach(viewModel.decks, id: \.id) { deck in
                                    NavigationLink(value: deck.id) {
                                        MWDeckCard(
                                            title: deck.title,
                                            subTopicCount: 0,
                                            cardCount: deck.cardCount,
                                            dueCount: viewModel.dueCountsByDeck[deck.id] ?? 0,
                                            accent: MWAccent(rawValue: deck.accentColor) ?? .amber
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .mwPadding(.horizontal, .l)
                        }
                    }
                } else {
                    ProgressView().foregroundStyle(MWColor.ink)
                }
            }
        }
        .navigationDestination(for: String.self) { deckId in
            DeckDetailView(deckId: deckId)
        }
        .mwBottomSheet(isPresented: $showingCreate) {
            CreateDeckView(userId: userId, onCreated: { try? viewModel?.load() })
        }
        .sheet(isPresented: $showingSearch) {
            SearchView()
        }
        .task {
            if viewModel == nil {
                viewModel = HomeViewModel(context: context, userId: userId)
            }
            try? viewModel?.load()
        }
    }
}
