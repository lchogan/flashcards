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
    public static let paper     = Color("mw/paper")
    public static let canvas    = Color("mw/canvas")
    public static let ink       = Color("mw/ink")
    public static let inkMuted  = Color("mw/inkMuted")
    public static let inkFaint  = Color("mw/inkFaint")
    public static let grid      = Color("mw/grid")

    /// Confidence accents for FSRS ratings (Again/Hard/Good/Easy).
    public static let again = Color("mw/again")
    public static let hard  = Color("mw/hard")
    public static let good  = Color("mw/good")
    public static let easy  = Color("mw/easy")
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
        .init(name: "easy", color: easy)
    ]
}
