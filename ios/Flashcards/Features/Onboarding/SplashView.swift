//
//  SplashView.swift
//  Flashcards
//
//  Purpose: First screen a user sees at cold launch. A brief Modernist
//           hero card (eyebrow + display headline on the canvas) held
//           long enough to register as intentional, then replaced by
//           `Intro1View` via `RootView`'s routing.
//  Dependencies: SwiftUI (View, VStack), `MWScreen`, `MWEyebrow`,
//                `MWSpacing`, `MWType`, `MWColor`.
//  Key concepts: Stateless — the hold duration lives in `RootView`'s
//                `.task` so this view can be reused (or snapshot-tested)
//                without a timer baked in. Intentionally shallow so any
//                future splash animation can bolt on here without
//                touching routing.
//

import SwiftUI

/// Onboarding splash screen. Eyebrow + display headline on the canvas; held briefly
/// by `RootView` before routing to `Intro1View`.
struct SplashView: View {
    /// Renders the eyebrow and display headline centered on the screen canvas.
    var body: some View {
        MWScreen {
            VStack(spacing: MWSpacing.l) {
                MWEyebrow("Flashcards")
                Text("Learn on purpose.")
                    .font(MWType.display).foregroundStyle(MWColor.ink)
            }
        }
    }
}
