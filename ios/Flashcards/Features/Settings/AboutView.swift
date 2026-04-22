//
//  AboutView.swift
//  Flashcards
//
//  Purpose: About-the-app + legal links + app version. Uses the current
//           DS tokens; no new hex or spacing values inline.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        MWScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    MWEyebrow("About")

                    Text("About spaced repetition")
                        .font(MWType.headingL)
                        .foregroundStyle(MWColor.ink)

                    Text(
                        """
                        Flashcards uses FSRS-6, a modern spaced-repetition algorithm that learns how \
                        you forget. Each review updates a hidden memory model for that card, so you \
                        see cards right as they're about to slip away.
                        """
                    )
                    .font(MWType.bodyL)
                    .foregroundStyle(MWColor.inkMuted)

                    MWDivider()

                    MWFormRow(title: "Version", value: Bundle.main.mwAppVersion) {
                        EmptyView()
                    }
                    MWDivider()
                    MWFormRow(
                        title: "Privacy policy",
                        onTap: { openURL("https://flashcards.app/privacy") },
                        accessory: { MWIcon(.chevronRight, size: 16) },
                    )
                    MWDivider()
                    MWFormRow(
                        title: "Terms of service",
                        onTap: { openURL("https://flashcards.app/terms") },
                        accessory: { MWIcon(.chevronRight, size: 16) },
                    )
                }
                .mwPadding(.all, .xl)
            }
        }
        .navigationTitle("About")
    }

    private func openURL(_ string: String) {
        if let url = URL(string: string) {
            UIApplication.shared.open(url)
        }
    }
}

private extension Bundle {
    var mwAppVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
    }
}
