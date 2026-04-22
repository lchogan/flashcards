//
//  MWScreen.swift
//  Flashcards
//
//  Purpose: Root screen container for every top-level view. Applies the canvas
//           background, opts the content into the safe-area by default, and
//           optionally overlays the Modernist 4pt hairline grid for a design
//           debug / editorial feel.
//  Dependencies: SwiftUI (View, ZStack, Canvas, Path), `MWColor`, `MWBorder`,
//                `MWType` (preview only).
//  Key concepts: The grid is a feature-flaggable Modernist detail — off by
//                default so production screens stay clean, on when a layout
//                wants to expose the underlying rhythm. `MWGridOverlay` is an
//                implementation detail and stays `private`; consumers toggle
//                the grid via `showsGrid` on `MWScreen`.
//

import SwiftUI

/// Root screen container. Applies canvas background, safe-area handling,
/// and optional grid overlay (Modernist detail — feature-flaggable).
public struct MWScreen<Content: View>: View {
    /// When `true`, renders the hairline 4pt grid overlay above the canvas and
    /// below `content`. Off by default.
    let showsGrid: Bool
    /// The screen's primary content, rendered above the canvas (and grid).
    @ViewBuilder let content: () -> Content

    /// Creates a screen root.
    /// - Parameters:
    ///   - showsGrid: Whether to render the 4pt hairline grid overlay. Defaults to `false`.
    ///   - content: The screen's content.
    public init(showsGrid: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.showsGrid = showsGrid
        self.content = content
    }

    public var body: some View {
        ZStack {
            MWColor.canvas.ignoresSafeArea()
            if showsGrid { MWGridOverlay().allowsHitTesting(false) }
            content()
        }
    }
}

/// Hairline 4pt grid drawn in `MWColor.grid` at 40% opacity. Implementation
/// detail of `MWScreen`; kept `private` so consumers can only enable it via
/// `MWScreen(showsGrid: true)`.
private struct MWGridOverlay: View {
    /// Grid spacing in points. 4pt is the Modernist base rhythm.
    let step: CGFloat = 4
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var x: CGFloat = 0
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            ctx.stroke(path, with: .color(MWColor.grid.opacity(0.4)), lineWidth: MWBorder.hair)
        }
    }
}

#Preview("MWScreen with grid") {
    MWScreen(showsGrid: true) {
        Text("Hello Modernist Workshop").font(MWType.headingM).foregroundStyle(MWColor.ink)
    }
}
