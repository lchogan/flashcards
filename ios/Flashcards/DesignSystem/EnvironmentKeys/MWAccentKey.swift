//
//  MWAccentKey.swift
//  Flashcards
//
//  Purpose: SwiftUI `EnvironmentKey` that threads a per-deck accent color
//           through the view tree. Components read `@Environment(\.mwAccent)`
//           so the active deck's tint propagates without prop-drilling.
//  Dependencies: SwiftUI (EnvironmentKey, EnvironmentValues, View), MWColor.
//  Key concepts: Default is `MWColor.ink` — screens outside a deck context
//                render with the neutral ink token. Set the accent near the
//                root of a deck-scoped view via the `.mwAccent(_:)` modifier.
//

import SwiftUI

/// Environment key backing `EnvironmentValues.mwAccent`.
///
/// Defaults to `MWColor.ink` so any view rendered outside a deck scope
/// falls back to the neutral ink tone.
private struct MWAccentKey: EnvironmentKey {
    static let defaultValue: Color = MWColor.ink
}

public extension EnvironmentValues {
    /// Per-deck accent color. Read via `@Environment(\.mwAccent)`.
    var mwAccent: Color {
        get { self[MWAccentKey.self] }
        set { self[MWAccentKey.self] = newValue }
    }
}

public extension View {
    /// Scopes the `mwAccent` environment value for the receiver and its descendants.
    /// - Parameter color: The accent color (usually an `MWAccent.color`).
    /// - Returns: A view whose subtree reads the supplied accent colour via
    ///   `@Environment(\.mwAccent)`.
    func mwAccent(_ color: Color) -> some View { environment(\.mwAccent, color) }
}
