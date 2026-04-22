//
//  StudySettingsView.swift
//  Flashcards
//
//  Purpose: Daily-goal and new-card-limit steppers. new_card_limit > 10
//           triggers the `newCardLimitAbove10` entitlement gate.
//  Dependencies: SwiftUI, EntitlementsManager, PaywallView.
//

import SwiftUI

struct StudySettingsView: View {
    @Environment(EntitlementsManager.self) private var entitlements
    @AppStorage("mw.dailyGoal") private var dailyGoal: Int = 20
    @AppStorage("mw.dailyNewCardLimit") private var dailyNewCardLimit: Int = 10
    @State private var paywallReason: EntitlementKey?

    var body: some View {
        MWScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    MWSection("Daily goal") {
                        Stepper("\(dailyGoal) cards", value: $dailyGoal, in: 1...500)
                            .font(MWType.bodyL)
                            .foregroundStyle(MWColor.ink)
                    }

                    MWSection("Daily new-card limit") {
                        Stepper(
                            "\(dailyNewCardLimit) cards",
                            value: Binding(
                                get: { dailyNewCardLimit },
                                set: { newValue in
                                    if newValue > 10,
                                        case .paywall(let reason, _) = entitlements.can(.newCardLimitAbove10).outcome
                                    {
                                        paywallReason = reason
                                        return
                                    }
                                    dailyNewCardLimit = newValue
                                }
                            ), in: 1...50
                        )
                        .font(MWType.bodyL)
                        .foregroundStyle(MWColor.ink)
                    }
                }
                .mwPadding(.all, .xl)
            }
        }
        .sheet(item: $paywallReason) { reason in
            PaywallView(reason: reason)
        }
        .navigationTitle("Study")
    }
}
