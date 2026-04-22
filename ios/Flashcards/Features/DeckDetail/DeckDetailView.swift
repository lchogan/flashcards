/// DeckDetailView.swift
///
/// Placeholder — replaced in Task 2.14 with a Cards/History tab host. This stub
/// exists so HomeView can compile against a real symbol while the deck detail
/// feature is still being built.
///
/// Dependencies: SwiftUI.

import SwiftUI

struct DeckDetailView: View {
    let deckId: String

    var body: some View {
        MWScreen {
            MWEmptyState(title: "Deck detail coming in 2.14", message: deckId)
        }
    }
}
