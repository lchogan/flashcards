//
//  RootView.swift
//  Flashcards
//
//  Purpose: Top-level view mounted by `FlashcardsApp`. Owns the
//           `AuthManager` and the onboarding `step` enum, routing the
//           user through Splash → Intro1 → Intro2 → SignUpWall →
//           MagicLinkSent while `auth.state` is not yet `.signedIn`.
//           Once authenticated it swaps in a placeholder stand-in for
//           the Phase 2 home screen.
//  Dependencies: SwiftUI, `AppState`, `AuthManager`, `APIClient`,
//                onboarding views (`SplashView`, `Intro1View`,
//                `Intro2View`, `SignUpWallView`, `MagicLinkSentView`),
//                `MWType`, `MWColor`.
//  Key concepts: `auth` is held via `@State` so SwiftUI owns its
//                lifetime for the scene. `step` is the onboarding
//                cursor; once `auth.state` becomes `.signedIn` the
//                `switch` short-circuits past it entirely and the
//                cursor becomes irrelevant. Magic-link completion is
//                driven from the App-level `.onOpenURL` handler, which
//                posts `Notification.Name.mwMagicLinkToken`; the
//                notification observer `.task` below awaits that
//                stream and calls `AuthManager.consumeMagicLink(token:)`,
//                which flips `auth.state` and causes this view to
//                re-route. `appState` is kept in scope for downstream
//                tasks that will read subscription / sync projections
//                off it.
//

import SwiftUI

/// Root view for the Flashcards app. Owns `AuthManager` and drives the
/// onboarding step machine; switches to a signed-in placeholder once
/// `auth.state == .signedIn`.
struct RootView: View {
    @Environment(AppState.self) private var appState
    // Hardcoded localhost base URL — placeholder. A later Phase 0 task wires
    // a real configuration source (build config / environment) and removes
    // this literal. Kept explicit so grep picks it up when that task lands.
    // swiftlint:disable:next todo
    // TODO: Replace hardcoded localhost base URL with build-config-driven value.
    @State private var auth = AuthManager(
        api: APIClient(baseURL: URL(string: "http://localhost:8000")!) { nil }
    )
    @State private var step: Step = .splash
    @State private var emailSent: String?

    /// Onboarding cursor. Advanced by the intro screens' continue
    /// closures and by the magic-link request path.
    enum Step { case splash, intro1, intro2, signup, magicLinkSent }

    /// Routes on `auth.state` first — signed-in short-circuits to a
    /// placeholder; otherwise the onboarding `step` decides what to
    /// render. `auth.restore()` runs once on appear via `.task`.
    var body: some View {
        Group {
            switch auth.state {
            case .signedIn:
                Text("Signed in — home coming in Phase 2.")
                    .font(MWType.headingM).foregroundStyle(MWColor.ink)
            default:
                switch step {
                case .splash: SplashView().task {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    step = .intro1
                }
                case .intro1: Intro1View { step = .intro2 }
                case .intro2: Intro2View { step = .signup }
                case .signup: SignUpWallView(
                    onAppleSignIn: {
                        try? await auth.signInWithApple()
                    },
                    onRequestMagicLink: { email in
                        try? await auth.requestMagicLink(email: email)
                        emailSent = email
                        step = .magicLinkSent
                    }
                )
                case .magicLinkSent:
                    MagicLinkSentView(email: emailSent ?? "")
                }
            }
        }
        .task { await auth.restore() }
        .task {
            // Magic-link fan-in: `FlashcardsApp`'s `.onOpenURL` posts
            // `mwMagicLinkToken` with the parsed token as `object`. We
            // await that stream here and hand the token to
            // `AuthManager.consumeMagicLink(token:)`. Errors are
            // currently swallowed — a later task will surface a
            // user-visible failure state for a bad/expired token.
            for await note in NotificationCenter.default.notifications(named: .mwMagicLinkToken) {
                if let token = note.object as? String {
                    try? await auth.consumeMagicLink(token: token)
                }
            }
        }
    }
}
