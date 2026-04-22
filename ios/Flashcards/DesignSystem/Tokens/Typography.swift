//
//  Typography.swift
//  Flashcards
//
//  Purpose: Design system typography tokens. Defines the Modernist type scale
//           used across every screen and component.
//  Dependencies: SwiftUI (Font).
//  Key concepts: All text in the app must be styled via `MWType.*`. The scale
//                mirrors Mockup/mw/01-tokens.jsx. Tracking adjustments (e.g.
//                eyebrow labels) are applied at call sites via `.tracking(...)`.
//

import SwiftUI

/// Design system typography tokens.
///
/// Scale taken from Mockup/mw/01-tokens.jsx. Tracking adjustments applied via `.tracking(...)`.
public enum MWType {
    /// Display heading, 40pt bold. Reserved for hero screens and top-of-page titles.
    public static let display = Font.custom("SF Pro Display", size: 40).weight(.bold)
    /// Large heading, 28pt semibold. Section titles.
    public static let headingL = Font.custom("SF Pro Display", size: 28).weight(.semibold)
    /// Medium heading, 20pt semibold. Card titles, dialog headings.
    public static let headingM = Font.custom("SF Pro Display", size: 20).weight(.semibold)
    /// Large body copy, 16pt regular.
    public static let bodyL = Font.custom("SF Pro Text", size: 16).weight(.regular)
    /// Default body copy, 14pt regular.
    public static let body = Font.custom("SF Pro Text", size: 14).weight(.regular)
    /// Small body copy, 12pt regular. Metadata, captions.
    public static let bodyS = Font.custom("SF Pro Text", size: 12).weight(.regular)
    /// Eyebrow label, 10pt medium. Use with `eyebrowTracking`.
    public static let eyebrow = Font.custom("SF Pro Text", size: 10).weight(.medium)
    /// Monospaced numerals/IDs, 13pt regular.
    public static let mono = Font.custom("SF Mono", size: 13).weight(.regular)

    /// Eyebrow tracking: 0.8pt.
    public static let eyebrowTracking: CGFloat = 0.8
}

#Preview("Typography scale") {
    VStack(alignment: .leading, spacing: 12) {
        Text("Display 40").font(MWType.display)
        Text("Heading L 28").font(MWType.headingL)
        Text("Heading M 20").font(MWType.headingM)
        Text("Body L 16").font(MWType.bodyL)
        Text("Body 14").font(MWType.body)
        Text("Body S 12").font(MWType.bodyS)
        Text("EYEBROW 10").font(MWType.eyebrow).tracking(MWType.eyebrowTracking)
        Text("mono 13").font(MWType.mono)
    }
    .padding()
}
