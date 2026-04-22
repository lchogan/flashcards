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

import SwiftData
import SwiftUI

/// Root view for the Flashcards app. Owns `AuthManager` and drives the
/// onboarding step machine; switches to a signed-in placeholder once
/// `auth.state == .signedIn`.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
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
            case .signedIn(let userId, _):
                NavigationStack {
                    HomeView(userId: userId)
                }
            default:
                switch step {
                case .splash:
                    SplashView().task {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        step = .intro1
                    }
                case .intro1: Intro1View { step = .intro2 }
                case .intro2: Intro2View { step = .signup }
                case .signup:
                    SignUpWallView(
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
        .task {
            if UITestLaunch.isActive {
                auth.state = .signedIn(userId: UITestLaunch.stubUserId, email: nil)
                appState.authStatus = .authenticated(userId: UITestLaunch.stubUserId)
                return
            }
            await auth.restore()
        }
        // Magic-link fan-in: `FlashcardsApp`'s `.onOpenURL` posts
        // `mwMagicLinkToken` with the parsed token as `object`. We
        // subscribe here via `.onReceive` (Combine publisher) and hand
        // the token to `AuthManager.consumeMagicLink(token:)`.
        //
        // We previously used `.task { for await note in
        // NotificationCenter.default.notifications(named:) ... }`, which
        // compiles against the iOS 18 SDK (where `Foundation.Notification`
        // is Sendable) but fails under Swift 6 strict concurrency on our
        // iOS 17 deployment target — `Notification` is non-Sendable
        // there and can't cross the MainActor boundary. `.onReceive` is
        // MainActor-isolated by construction, so the publisher's values
        // never leave the main actor and Sendability doesn't apply.
        //
        // Errors from `consumeMagicLink` are currently swallowed — a
        // later task will surface a user-visible failure state for a
        // bad/expired token.
        .onReceive(NotificationCenter.default.publisher(for: .mwMagicLinkToken)) { note in
            guard let token = note.object as? String else {
                return
            }
            Task { try? await auth.consumeMagicLink(token: token) }
        }
        // Streak-at-risk nudge: when the app is backgrounded (or never
        // opened after breakfast), re-evaluate and schedule a one-shot 20:00
        // reminder if the streak needs rescuing. Scheduled every foreground
        // so it self-cancels the moment the user logs a review.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }
            let monitor = StreakMonitor(context: modelContext)
            let scheduler = ReminderScheduler()
            Task {
                if monitor.streakAtRisk() {
                    await scheduler.schedule(
                        time: DateComponents(hour: 20, minute: 0),
                        identifier: "mw.streak.nudge",
                        title: "Your streak is waiting.",
                        body: "A quick session keeps it alive.",
                        category: ReminderScheduler.streakCategory,
                    )
                } else {
                    await scheduler.cancel(identifier: "mw.streak.nudge")
                }
            }
        }
    }
}
