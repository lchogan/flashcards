//
//  RootView.swift
//  Flashcards
//
//  Purpose: Top-level view mounted by `FlashcardsApp`. In Phase 0 this is a
//           thin scaffold that reads `AppState` from the environment and
//           renders a design-system-styled placeholder — just enough to
//           prove the environment wiring and token chain are intact.
//  Dependencies: SwiftUI, `AppState`, `MWScreen`, `MWEyebrow`, `MWSpacing`,
//                `MWType`, `MWColor`.
//  Key concepts: No routing, no navigation stack, no auth branching. Those
//                arrive in Tasks 0.39–0.40. This view intentionally stays
//                shallow so the routing task can replace its body without
//                fighting existing hierarchy.
//

import SwiftUI

/// Root view for the Flashcards app. Thin scaffold reading `AppState` from the
/// environment; Phase 0 placeholder pending routing in Task 0.39.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        MWScreen {
            VStack(spacing: MWSpacing.l) {
                MWEyebrow("Flashcards")
                Text("Phase 0 scaffold").font(MWType.headingM).foregroundStyle(MWColor.ink)
                Text("Auth status: \(String(describing: appState.authStatus))")
                    .font(MWType.body).foregroundStyle(MWColor.inkMuted)
            }
        }
    }
}

#Preview {
    RootView().environment(AppState())
}
