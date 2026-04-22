//
//  AppearanceSettingsView.swift
//  Flashcards
//
//  Purpose: System/Light/Dark theme preference. Stored via @AppStorage;
//           consumed by the root ColorScheme modifier.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("mw.themePreference") private var preference: String = "system"

    var body: some View {
        MWScreen {
            VStack(alignment: .leading, spacing: MWSpacing.l) {
                MWSection("Theme") {
                    Picker("", selection: $preference) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .mwPadding(.all, .xl)
        }
        .navigationTitle("Appearance")
    }
}
