//
//  MWStackedDeckPaper.swift
//  Flashcards
//
//  Purpose: Stacked-paper backdrop used behind deck summary cards on the
//           HomeView grid. Draws three rounded sheets, offset and dimmed, with
//           the caller's content on top.
//  Dependencies: SwiftUI, MWColor, MWRadius, MWBorder.
//

import SwiftUI

/// Three-sheet stacked-paper illusion behind `content`.
public struct MWStackedDeckPaper<Content: View>: View {
    @ViewBuilder let content: () -> Content

    /// Creates a new instance.
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    /// View body.
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MWRadius.m)
                .fill(MWColor.paper)
                .mwStroke(color: MWColor.ink, width: MWBorder.defaultWidth, cornerRadius: MWRadius.m)
                .offset(x: 6, y: 6)
                .opacity(0.65)
            RoundedRectangle(cornerRadius: MWRadius.m)
                .fill(MWColor.paper)
                .mwStroke(color: MWColor.ink, width: MWBorder.defaultWidth, cornerRadius: MWRadius.m)
                .offset(x: 3, y: 3)
                .opacity(0.85)
            content()
                .background(MWColor.paper)
                .mwCornerRadius(.m)
                .mwStroke(color: MWColor.ink, width: MWBorder.defaultWidth, cornerRadius: MWRadius.m)
        }
    }
}
