//
//  SubscriptionSettingsView.swift
//  Flashcards
//
//  Purpose: Surfaces the user's current plan. Free users get a paywall CTA;
//           Plus users get "Manage subscription" (deep-link to the App Store
//           subscription screen) and the restore-purchases action.
//

import SwiftUI

struct SubscriptionSettingsView: View {
    @Environment(PurchasesManager.self) private var purchases
    @Environment(EntitlementsManager.self) private var entitlements
    @State private var showingPaywall = false
    @State private var isRestoring = false
    @State private var restoreError: String?

    var body: some View {
        MWScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    MWEyebrow("Current plan")

                    Text(entitlements.planKey.capitalized)
                        .font(MWType.headingL)
                        .foregroundStyle(MWColor.ink)

                    if entitlements.planKey == "free" {
                        MWButton("Upgrade to Plus") {
                            showingPaywall = true
                        }
                    } else {
                        MWButton("Manage subscription") {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }

                    Button("Restore purchases") {
                        Task { await restore() }
                    }
                    .font(MWType.body)
                    .foregroundStyle(MWColor.inkMuted)
                    .disabled(isRestoring)

                    if let restoreError {
                        Text(restoreError)
                            .font(MWType.body)
                            .foregroundStyle(MWColor.again)
                    }
                }
                .mwPadding(.all, .xl)
            }
        }
        .navigationTitle("Subscription")
        .sheet(isPresented: $showingPaywall) {
            PaywallView(reason: .decksCreate)
        }
    }

    private func restore() async {
        isRestoring = true
        restoreError = nil
        defer { isRestoring = false }
        do {
            try await purchases.restore()
        } catch {
            restoreError = "Nothing to restore, or the store is unreachable."
        }
    }
}
