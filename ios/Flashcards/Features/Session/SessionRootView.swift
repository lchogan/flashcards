/// SessionRootView.swift
///
/// Placeholder — replaced in Task 2.17 with the Smart Study session host.
///
/// Dependencies: SwiftUI.

import SwiftUI

struct SessionRootView: View {
    let deckId: String
    let onDismiss: () -> Void

    var body: some View {
        MWScreen {
            MWEmptyState(
                title: "Study coming in 2.17",
                message: deckId,
                ctaTitle: "Close",
                onCtaTap: onDismiss
            )
        }
    }
}
