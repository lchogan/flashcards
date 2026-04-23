//
//  PaywallView.swift
//  Flashcards
//
//  Purpose: Renders the paywall sheet shown whenever an entitlement check
//           returns .paywall. Copy is driven by the triggering
//           EntitlementKey so the headline + subline match the gate that
//           blocked the user (e.g. "You've hit 5 decks" vs "Add a second
//           reminder with Plus"). The CTA pipes through PurchasesManager;
//           restore button re-verifies an existing purchase.
//  Dependencies: SwiftUI, DS tokens + atoms, EntitlementKey,
//                PurchasesManager (wired in 3.9).
//  Key concepts: One sheet, many reasons. PaywallCopy.map holds the gate →
//                copy table so we never have paywall-specific branching
//                inside the view body.
//

import SwiftUI

/// Paywall modal. Presented by any gated call site when an entitlement
/// check returns `.paywall`. Copy is keyed off the triggering
/// `EntitlementKey` via `PaywallCopy`.
internal struct PaywallView: View {
    internal let reason: EntitlementKey
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchasesManager.self) private var purchases

    @State private var isPurchasing = false
    @State private var errorMessage: String?

    internal init(reason: EntitlementKey) {
        self.reason = reason
    }

    internal var body: some View {
        let copy = PaywallCopy.map[reason] ?? PaywallCopy.fallback

        MWScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    MWEyebrow(copy.eyebrow)

                    Text(copy.headline)
                        .font(MWType.headingL)
                        .foregroundStyle(MWColor.ink)

                    Text(copy.body)
                        .font(MWType.bodyL)
                        .foregroundStyle(MWColor.inkMuted)

                    VStack(alignment: .leading, spacing: MWSpacing.s) {
                        ForEach(copy.bullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: MWSpacing.s) {
                                Text("—").font(MWType.bodyL).foregroundStyle(MWColor.ink)
                                Text(bullet).font(MWType.bodyL).foregroundStyle(MWColor.ink)
                            }
                        }
                    }
                    .mwPadding(.vertical, .m)

                    if let message = errorMessage {
                        Text(message)
                            .font(MWType.body)
                            .foregroundStyle(MWColor.again)
                    }

                    MWButton(copy.ctaLabel) {
                        Task { await purchase() }
                    }
                    .disabled(isPurchasing)

                    Button("Restore purchases") {
                        Task { await restore() }
                    }
                    .font(MWType.body)
                    .foregroundStyle(MWColor.inkMuted)
                    .disabled(isPurchasing)
                }
                .mwPadding(.all, .xl)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func purchase() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let outcome = try await purchases.purchase(productId: PurchasesManager.plusMonthlyProductId)
            if outcome == .success {
                dismiss()
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
        }
    }

    private func restore() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            try await purchases.restore()
            dismiss()
        } catch {
            errorMessage = "Couldn't restore. Try signing in on the device with your original Apple ID."
        }
    }
}

/// Copy block shown on the paywall sheet, keyed off the triggering gate.
internal struct PaywallCopyEntry: Sendable {
    internal let eyebrow: String
    internal let headline: String
    internal let body: String
    internal let bullets: [String]
    internal let ctaLabel: String
}

/// Static table mapping each `EntitlementKey` to the copy shown when it
/// triggers the paywall. New entitlements must add a row here or the
/// caller will fall through to `fallback`.
internal enum PaywallCopy {
    internal static let fallback = PaywallCopyEntry(
        eyebrow: "Upgrade",
        headline: "Unlock Plus",
        body: "Everything in Flashcards, without the guardrails.",
        bullets: [
            "Unlimited decks and cards",
            "More reminders, more control",
            "Smart mode stays smart",
        ],
        ctaLabel: "Upgrade to Plus"
    )

    internal static let map: [EntitlementKey: PaywallCopyEntry] = [
        .decksCreate: PaywallCopyEntry(
            eyebrow: "Limit reached",
            headline: "You've got 5 decks.",
            body: "Plus removes the cap so you can organize without compromise.",
            bullets: [
                "Unlimited decks",
                "Unlimited cards per deck",
                "Up to 3 daily reminders",
            ],
            ctaLabel: "Upgrade to Plus"
        ),
        .cardsCreateInDeck: PaywallCopyEntry(
            eyebrow: "Limit reached",
            headline: "This deck is full.",
            body: "Free decks hold 200 cards. Plus removes the cap.",
            bullets: [
                "Unlimited cards per deck",
                "Unlimited total cards",
                "Higher new-card daily limit",
            ],
            ctaLabel: "Upgrade to Plus"
        ),
        .cardsCreateTotal: PaywallCopyEntry(
            eyebrow: "Limit reached",
            headline: "You've reached 500 cards.",
            body: "Plus lifts the total-card cap across all your decks.",
            bullets: [
                "Unlimited cards across all decks",
                "Unlimited decks",
                "More reminders",
            ],
            ctaLabel: "Upgrade to Plus"
        ),
        .remindersAdd: PaywallCopyEntry(
            eyebrow: "Reminder locked",
            headline: "Add more reminders.",
            body: "Free gives you one daily reminder. Plus raises that to three.",
            bullets: [
                "Up to 3 daily reminders",
                "Unlimited decks and cards",
                "Higher new-card daily limit",
            ],
            ctaLabel: "Upgrade to Plus"
        ),
        .newCardLimitAbove10: PaywallCopyEntry(
            eyebrow: "Locked",
            headline: "Faster progress.",
            body: "Free caps new-card introduction at 10 per day. Plus raises that ceiling.",
            bullets: [
                "Higher new-card daily limit",
                "Unlimited decks and cards",
                "More reminders",
            ],
            ctaLabel: "Upgrade to Plus"
        ),
    ]
}

#if DEBUG

/// Stub APIClient for Previews — never actually hits the network.
private final class PreviewStubAPI: APIClientProtocol, @unchecked Sendable {
    func send<R>(_ endpoint: APIEndpoint<R>) async throws -> R where R: Decodable & Sendable {
        throw APIError.offline
    }
}

#Preview("Paywall — decksCreate") {
    let purchases = PurchasesManager(api: PreviewStubAPI())
    return NavigationStack {
        PaywallView(reason: .decksCreate)
    }
    .environment(purchases)
}

#Preview("Paywall — remindersAdd") {
    let purchases = PurchasesManager(api: PreviewStubAPI())
    return NavigationStack {
        PaywallView(reason: .remindersAdd)
    }
    .environment(purchases)
}

#Preview("Paywall — cardsCreateInDeck") {
    let purchases = PurchasesManager(api: PreviewStubAPI())
    return NavigationStack {
        PaywallView(reason: .cardsCreateInDeck)
    }
    .environment(purchases)
}

#endif
