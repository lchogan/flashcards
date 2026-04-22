/// CreateCardView.swift
///
/// Placeholder — replaced in Task 2.15 with a front/back + sub-topic form.
///
/// Dependencies: SwiftUI.

import SwiftUI

struct CreateCardView: View {
    let deckId: String
    let onSaved: () -> Void

    var body: some View {
        MWScreen {
            MWEmptyState(title: "Create card coming in 2.15", message: deckId)
        }
    }
}
