//
//  Colors.swift
//  Flashcards
//
//  Purpose: Design system color tokens backed by the `mw/*` Asset Catalog
//           namespace. Each token resolves to a light + dark appearance pair.
//  Dependencies: SwiftUI (Color), Assets.xcassets/mw/*.colorset.
//  Key concepts: All UI surfaces must consume colors through `MWColor` — the
//                build-time lint rule (Task 0.12) forbids `Color(hex:)` and
//                SwiftUI's named colors outside this file.
//

import SwiftUI

/// Design system color tokens.
///
/// Consumers: all files under `DesignSystem/Components/` and `Features/`.
/// Never reference `Color(hex:)` or SwiftUI's named colors (`.red`, `.black`, …)
/// from outside this file — SwiftLint (Task 0.12) enforces this at build time.
public enum MWColor {
    /// Primary surface — off-white "paper" used for cards and chrome.
    public static let paper = Color("mw/paper")
    /// Root canvas — slightly darker than paper; used for screen backgrounds.
    public static let canvas = Color("mw/canvas")
    /// Ink — primary text + borders.
    public static let ink = Color("mw/ink")
    /// Secondary ink for subtitles, meta labels, eyebrows.
    public static let inkMuted = Color("mw/inkMuted")
    /// Tertiary ink for de-emphasized helper text.
    public static let inkFaint = Color("mw/inkFaint")
    /// Hairline grid overlay used by `MWScreen` for the Modernist backdrop.
    public static let grid = Color("mw/grid")

    /// "Again" rating tint — rust red.
    public static let again = Color("mw/again")
    /// "Hard" rating tint — amber.
    public static let hard = Color("mw/hard")
    /// "Good" rating tint — moss green.
    public static let good = Color("mw/good")
    /// "Easy" rating tint — slate blue.
    public static let easy = Color("mw/easy")
}

#Preview("Color swatches") {
    ScrollView {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(MWColor.allPairs, id: \.name) { pair in
                HStack {
                    Rectangle().fill(pair.color).frame(width: 48, height: 48)
                    Text(pair.name)
                }
            }
        }
        .padding()
    }
}

extension MWColor {
    fileprivate struct Pair {
        let name: String
        let color: Color
    }

    fileprivate static let allPairs: [Pair] = [
        .init(name: "paper", color: paper),
        .init(name: "canvas", color: canvas),
        .init(name: "ink", color: ink),
        .init(name: "inkMuted", color: inkMuted),
        .init(name: "inkFaint", color: inkFaint),
        .init(name: "grid", color: grid),
        .init(name: "again", color: again),
        .init(name: "hard", color: hard),
        .init(name: "good", color: good),
        .init(name: "easy", color: easy),
    ]
}

/// Per-deck accent palette. Each case resolves to a light + dark asset pair
/// under `mw/accent/<rawValue>` in `Assets.xcassets`.
///
/// Decks persist their accent by storing the `rawValue`; the UI reads the
/// resulting `Color` via `.mwAccent(_:)` (see `MWAccentKey`).
public enum MWAccent: String, CaseIterable, Codable {
    case amber, moss, iris, rust, slate

    /// Resolved `Color` backed by the Asset Catalog.
    public var color: Color { Color("mw/accent/\(rawValue)") }
}
