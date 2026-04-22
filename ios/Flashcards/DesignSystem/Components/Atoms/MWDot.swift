//
//  MWDot.swift
//  Flashcards
//
//  Purpose: Tiny filled-circle atom used as an inline indicator (unread marks,
//           status bullets, list glyphs).
//  Dependencies: SwiftUI (View, Circle), `MWColor`.
//  Key concepts: `size` is a raw `CGFloat` rather than a spacing/control token
//                because it represents a glyph diameter, not padding or a
//                control dimension. Default diameter of 8pt matches the
//                Modernist dot-bullet spec; override per call site when needed.
//

import SwiftUI

/// Filled circle atom used as an inline status or bullet glyph.
public struct MWDot: View {
    let color: Color
    let size: CGFloat

    /// Creates a filled dot.
    /// - Parameters:
    ///   - color: Fill colour. Defaults to `MWColor.ink`.
    ///   - size: Diameter in points. Defaults to `8`.
    public init(color: Color = MWColor.ink, size: CGFloat = 8) {
        self.color = color
        self.size = size
    }

    /// Renders a `Circle` filled with `color` at a `size`-square frame.
    public var body: some View { Circle().fill(color).frame(width: size, height: size) }
}

#Preview("MWDot") {
    MWDot()
        .mwPadding(.all, .l)
        .background(MWColor.canvas)
}
