//
//  FlashcardsApp.swift
//  Flashcards
//
//  Purpose: `@main` entry point. Owns the single `AppState` instance and
//           injects it into the SwiftUI environment before mounting
//           `RootView`. Also installs the scene-level `.onOpenURL`
//           handler that converts a magic-link universal link into a
//           `Notification` broadcast that `RootView` observes.
//  Dependencies: SwiftUI, `AppState`, `RootView`, `MagicLinkConsumer`,
//                `AnalyticsClient`.
//  Key concepts: `AppState` is held via `@State` so SwiftUI owns its
//                lifetime for the life of the scene. `.environment(appState)`
//                publishes it for any descendant to observe. The
//                `.onOpenURL` closure is kept trivially Sendable — it
//                parses the URL synchronously and posts to
//                `NotificationCenter`, delegating the async token
//                exchange to `RootView`'s observer task. Analytics
//                initialisation (Sentry + PostHog) runs once in `init()`
//                before the scene is constructed so the SDKs are ready
//                for the first event. SwiftData is not imported yet — it
//                will be added when the model container lands in a later
//                task.
//

import SwiftUI

@main
struct FlashcardsApp: App {
    @State private var appState = AppState()

    init() {
        AnalyticsClient.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView().environment(appState)
                .onOpenURL { url in
                    if let token = MagicLinkConsumer.extractToken(from: url) {
                        NotificationCenter.default.post(
                            name: .mwMagicLinkToken,
                            object: token
                        )
                    }
                }
        }
    }
}
