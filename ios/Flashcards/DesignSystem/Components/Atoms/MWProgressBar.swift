//
//  MWProgressBar.swift
//  Flashcards
//
//  Purpose: Bordered linear progress bar used in session chrome and settings.
//  Dependencies: SwiftUI, MWColor, MWBorder.
//  Key concepts: Clamps `progress` to [0, 1]. Height is expressed as a multiple
//                of `MWBorder.bold` so the bar stays proportionate to the rest
//                of the Modernist stroke language.
//

import SwiftUI

/// Horizontal progress bar with an ink stroke and ink fill.
public struct MWProgressBar: View {
    let progress: Double

    public init(progress: Double) {
        self.progress = max(0, min(1, progress))
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(MWColor.canvas)
                Rectangle().fill(MWColor.ink)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: MWBorder.bold * 2)
        .mwStroke(color: MWColor.ink, width: MWBorder.defaultWidth)
    }
}

#Preview("MWProgressBar") {
    VStack(spacing: MWSpacing.m) {
        MWProgressBar(progress: 0.0)
        MWProgressBar(progress: 0.33)
        MWProgressBar(progress: 0.66)
        MWProgressBar(progress: 1.0)
    }
    .mwPadding(.all, .l)
    .background(MWColor.canvas)
}
