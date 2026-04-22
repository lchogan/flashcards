//
//  Intro1View.swift
//  Flashcards
//
//  Purpose: First onboarding narrative screen. Pitches the app's core
//           premise — spaced repetition scheduled around the user's
//           memory — as a prelude to the sign-up wall.
//  Dependencies: SwiftUI (View, VStack, Spacer), `MWScreen`, `MWEyebrow`,
//                `MWButton`, `MWSpacing` / `MWSpacingToken`, `MWType`,
//                `MWColor`.
//  Key concepts: Stateless and purely presentational. The `onContinue`
//                closure is supplied by `RootView`, which owns the
//                onboarding `step` enum — this view never mutates
//                routing state directly, keeping it trivially testable
//                and snapshot-friendly.
//

import SwiftUI

/// First onboarding narrative screen. Stateless; delegates progression to
/// `onContinue`, which is supplied by `RootView`.
struct Intro1View: View {
    /// Invoked when the user taps "Continue". Supplied by the parent
    /// router (`RootView`) which advances the onboarding step.
    let onContinue: () -> Void

    /// Renders eyebrow + headline + body + a "Continue" primary button
    /// anchored to the bottom via a `Spacer`.
    var body: some View {
        MWScreen {
            VStack(alignment: .leading, spacing: MWSpacing.l) {
                MWEyebrow("01 — Welcome")
                Text("A spaced-repetition app that actually studies you.")
                    .font(MWType.headingL).foregroundStyle(MWColor.ink)
                Text("Flashcards schedules each card based on your memory, so short sessions beat long ones.")
                    .font(MWType.bodyL).foregroundStyle(MWColor.inkMuted)
                Spacer()
                MWButton("Continue", action: onContinue)
            }.mwPadding(.all, .xl)
        }
    }
}
