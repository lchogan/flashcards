/// CardEditView.swift
///
/// Placeholder — replaced in Task 2.15 with a front/back editor.
///
/// Dependencies: SwiftUI.

import SwiftUI

struct CardEditView: View {
    let card: CardEntity

    var body: some View {
        MWScreen {
            MWEmptyState(title: "Card edit coming in 2.15", message: card.id)
        }
    }
}
