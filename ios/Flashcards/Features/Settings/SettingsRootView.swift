//
//  SettingsRootView.swift
//  Flashcards
//
//  Purpose: Top-level Settings list. Navigates to Profile / Account /
//           Subscription / Study / Appearance / About sub-views.
//  Dependencies: SwiftUI, DS molecules (MWSection, MWFormRow, MWDivider,
//                MWIcon).
//

import SwiftUI

struct SettingsRootView: View {
    var body: some View {
        MWScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    MWEyebrow("Settings")

                    MWSection("Account") {
                        NavigationLink {
                            ProfileSettingsView()
                        } label: {
                            MWFormRow(title: "Profile") { MWIcon(.chevronRight, size: 16) }
                        }
                        MWDivider()
                        NavigationLink {
                            AccountSettingsView()
                        } label: {
                            MWFormRow(title: "Account") { MWIcon(.chevronRight, size: 16) }
                        }
                        MWDivider()
                        NavigationLink {
                            SubscriptionSettingsView()
                        } label: {
                            MWFormRow(title: "Subscription") { MWIcon(.chevronRight, size: 16) }
                        }
                    }

                    MWDivider()

                    MWSection("Preferences") {
                        NavigationLink {
                            StudySettingsView()
                        } label: {
                            MWFormRow(title: "Study") { MWIcon(.chevronRight, size: 16) }
                        }
                        MWDivider()
                        NavigationLink {
                            AppearanceSettingsView()
                        } label: {
                            MWFormRow(title: "Appearance") { MWIcon(.chevronRight, size: 16) }
                        }
                    }

                    MWDivider()

                    MWSection("About") {
                        NavigationLink {
                            AboutView()
                        } label: {
                            MWFormRow(title: "About Flashcards") { MWIcon(.chevronRight, size: 16) }
                        }
                    }
                }
                .mwPadding(.all, .xl)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
