//
//  MagicLinkSentView.swift
//  Flashcards
//
//  Purpose: Terminal onboarding confirmation shown after the user
//           requests a magic-link email. Tells them to check their
//           inbox and echoes the address we sent the link to.
//  Dependencies: SwiftUI (View, VStack, Text), `MWScreen`, `MWEyebrow`,
//                `MWSpacing` / `MWSpacingToken`, `MWType`, `MWColor`.
//  Key concepts: Stateless and passive — the "return to app" transition
//                is driven by the universal-link handler (future task)
//                calling `AuthManager.consumeMagicLink(token:)`, which
//                flips `auth.state` to `.signedIn` and causes `RootView`
//                to swap this screen out. Nothing here polls or times
//                out.
//

import SwiftUI

/// Magic-link-sent confirmation. Shown after `AuthManager.requestMagicLink`
/// returns; displays the address we mailed the link to and waits passively
/// for the universal-link round-trip to resolve the auth state.
struct MagicLinkSentView: View {
    /// The email address the magic-link was requested for. Rendered in
    /// mono type as a concrete receipt the user can double-check.
    let email: String

    /// Renders the confirmation copy and echoes `email` in mono type.
    var body: some View {
        MWScreen {
            VStack(alignment: .leading, spacing: MWSpacing.l) {
                MWEyebrow("Check your inbox")
                Text("We sent you a link.")
                    .font(MWType.headingL).foregroundStyle(MWColor.ink)
                Text("Tap it on this device — we'll bring you right back.")
                    .font(MWType.bodyL).foregroundStyle(MWColor.inkMuted)
                Text(email).font(MWType.mono).foregroundStyle(MWColor.ink)
            }.mwPadding(.all, .xl)
        }
    }
}
