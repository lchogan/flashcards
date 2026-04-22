//
//  FlashcardsApp.swift
//  Flashcards
//
//  Purpose: `@main` entry point. Owns the single `AppState` instance and
//           injects it into the SwiftUI environment before mounting
//           `RootView`. Also owns the SwiftData `ModelContainer` that
//           backs all 10 persistent entity types and exposes it to the
//           view hierarchy via `.modelContainer(container)`.
//           Installs the scene-level `.onOpenURL` handler that converts
//           a magic-link universal link into a `Notification` broadcast
//           that `RootView` observes.
//  Dependencies: SwiftUI, SwiftData, `AppState`, `RootView`,
//                `MagicLinkConsumer`, `AnalyticsClient`, all *Entity types.
//  Key concepts: `AppState` is held via `@State` so SwiftUI owns its
//                lifetime for the life of the scene. `.environment(appState)`
//                publishes it for any descendant to observe. The
//                `.onOpenURL` closure is kept trivially Sendable — it
//                parses the URL synchronously and posts to
//                `NotificationCenter`, delegating the async token
//                exchange to `RootView`'s observer task. Analytics
//                initialisation (Sentry + PostHog) runs once in `init()`
//                before the scene is constructed so the SDKs are ready
//                for the first event.
//

import SwiftData
import SwiftUI
import UIKit

/// UIApplicationDelegate shim so we can receive APNs token callbacks. iOS
/// only calls `didRegisterForRemoteNotifications...` on a UIApplication-
/// Delegate, not on SwiftUI's App — so we bridge through `@UIApplication-
/// DelegateAdaptor`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            await DeviceTokenRegistrar.register(tokenData: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AnalyticsClient.track("apns.register.fail", properties: ["error": String(describing: error)])
    }
}

@main
struct FlashcardsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @State private var entitlements: EntitlementsManager
    @State private var purchases: PurchasesManager
    let container: ModelContainer

    init() {
        AnalyticsClient.configure()

        // One APIClient shared between the entitlement and purchase surfaces
        // so both see the same auth token. AuthManager keeps its own client in
        // RootView for the unauthenticated auth flows.
        let tokenStore = TokenStore()
        let api = APIClient(baseURL: URL(string: "http://localhost:8000")!) {
            await tokenStore.access()
        }
        let entitlementsManager = EntitlementsManager(api: api)
        self._entitlements = State(initialValue: entitlementsManager)
        self._purchases = State(
            initialValue: PurchasesManager(
                api: api,
                refreshEntitlements: { @Sendable [weak entitlementsManager] in
                    await entitlementsManager?.load(force: true)
                }
            ))

        let schema: [any PersistentModel.Type] = [
            UserEntity.self, TopicEntity.self, DeckEntity.self, SubTopicEntity.self,
            CardEntity.self, CardSubTopicEntity.self, ReviewEntity.self,
            SessionEntity.self, AssetEntity.self, PendingMutationEntity.self,
        ]
        do {
            if UITestLaunch.isActive {
                // UI tests run against an in-memory store for deterministic,
                // clean-slate state on every launch.
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                container = try ModelContainer(for: Schema(schema), configurations: [config])
            } else {
                container = try ModelContainer(
                    for: UserEntity.self, TopicEntity.self, DeckEntity.self, SubTopicEntity.self,
                    CardEntity.self, CardSubTopicEntity.self, ReviewEntity.self,
                    SessionEntity.self, AssetEntity.self, PendingMutationEntity.self
                )
            }
        } catch {
            fatalError("Failed to initialise SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView().environment(appState)
                .environment(entitlements)
                .environment(purchases)
                .modelContainer(container)
                .task {
                    if UITestLaunch.isActive {
                        // UI tests run offline against an in-memory store;
                        // the real load() would hit a nonexistent backend
                        // and leave gated features blocked by the paywall.
                        entitlements.applyUnrestricted()
                    } else {
                        await entitlements.load()
                        await purchases.load()
                    }
                }
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
