//
//  MWDivider.swift
//  Flashcards
//
//  Purpose: Horizontal rule atom. Draws an ink-coloured line at the design-
//           system default border width — the Modernist-correct replacement
//           for SwiftUI's default `Divider` (which renders a faint system
//           separator).
//  Dependencies: SwiftUI (View, Rectangle), `MWColor`, `MWBorder`.
//  Key concepts: Uses `MWBorder.defaultWidth` directly for the height (not via
//                `mwStroke`) because the divider itself is the stroke. The
//                rectangle stretches to fill the container width; callers
//                control length by placing it in a constrained parent.
//

import SwiftUI

/// Horizontal rule drawn as an `MWColor.ink` rectangle at `MWBorder.defaultWidth`.
public struct MWDivider: View {
    /// Creates a full-width divider with no configuration.
    public init() {}

    /// Renders a horizontal rectangle at the default border width.
    public var body: some View {
        Rectangle().fill(MWColor.ink).frame(height: MWBorder.defaultWidth)
    }
}

#Preview("MWDivider") {
    MWDivider()
        .mwPadding(.all, .l)
        .background(MWColor.canvas)
}
