//
//  Intro2View.swift
//  Flashcards
//
//  Purpose: Second onboarding narrative screen. Sells the offline-first
//           posture — local-first writes with background sync — before
//           the user lands on the sign-up wall.
//  Dependencies: SwiftUI (View, VStack, Spacer), `MWScreen`, `MWEyebrow`,
//                `MWButton`, `MWSpacing` / `MWSpacingToken`, `MWType`,
//                `MWColor`.
//  Key concepts: Mirrors `Intro1View`'s shape deliberately so the
//                onboarding rhythm reads as a consistent two-beat intro.
//                Routing lives in the parent (`RootView`); this view is
//                stateless.
//

import SwiftUI

/// Second onboarding narrative screen. Stateless; delegates progression to
/// `onContinue`, which is supplied by `RootView`.
struct Intro2View: View {
    /// Invoked when the user taps "Continue". Supplied by the parent
    /// router (`RootView`) which advances the onboarding step to the
    /// sign-up wall.
    let onContinue: () -> Void

    /// Renders eyebrow + headline + body + a "Continue" primary button
    /// anchored to the bottom via a `Spacer`.
    var body: some View {
        MWScreen {
            VStack(alignment: .leading, spacing: MWSpacing.l) {
                MWEyebrow("02 — Offline by default")
                Text("Works anywhere. Syncs when you're back.")
                    .font(MWType.headingL).foregroundStyle(MWColor.ink)
                Text("Every study session, every new card — zero waiting on the network.")
                    .font(MWType.bodyL).foregroundStyle(MWColor.inkMuted)
                Spacer()
                MWButton("Continue", action: onContinue)
            }.mwPadding(.all, .xl)
        }
    }
}
