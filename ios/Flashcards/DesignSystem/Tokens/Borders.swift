//
//  Borders.swift
//  Flashcards
//
//  Purpose: Border-width tokens and the `mwStroke` modifier used to outline
//           Modernist surfaces (cards, chips, buttons).
//  Dependencies: SwiftUI (View, ViewModifier, RoundedRectangle), `MWColor`.
//  Key concepts: The Modernist language is border-first, shadow-averse. The
//                default border width is 1.5pt. Named `defaultWidth` rather
//                than `default` to avoid collision with the Swift keyword
//                (the backtick-escaped form compiles but reads worse at call
//                sites such as ``MWBorder.`default` ``).
//

import SwiftUI

/// Border width tokens.
public enum MWBorder {
    /// Hairline, 0.5pt. Subtle separators.
    public static let hair: CGFloat = 0.5
    /// Modernist default border, 1.5pt. Named to avoid shadowing the Swift `default` keyword.
    public static let defaultWidth: CGFloat = 1.5
    /// Bold border, 2.5pt. Focus states and emphasized surfaces.
    public static let bold: CGFloat = 2.5
}

/// Overlay stroke modifier. Draws a rectangular border around the content at
/// the specified color and width. When paired with a rounded-corner clip on the
/// same view, pass a matching `cornerRadius` so the stroke traces the rounded
/// outline instead of a sharp rectangle.
public struct MWStroke: ViewModifier {
    /// Stroke color.
    let color: Color
    /// Stroke width in points.
    let width: CGFloat
    /// Corner radius for the overlay shape. Defaults to `0` (sharp rectangle).
    /// Set this to match any `mwCornerRadius` applied upstream so the border
    /// lines up with the clipped fill.
    let cornerRadius: CGFloat

    /// Overlays a (optionally rounded) rectangular stroke on `content`.
    public func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius).stroke(color, lineWidth: width)
        )
    }
}

public extension View {
    /// Applies a design-system stroke in `MWColor.ink` at `MWBorder.defaultWidth` by default.
    ///
    /// - Parameters:
    ///   - color: Stroke color. Defaults to `MWColor.ink`.
    ///   - width: Stroke width in points. Defaults to `MWBorder.defaultWidth`.
    ///   - cornerRadius: Corner radius for the overlay shape. Defaults to `0`
    ///     (sharp rectangle). Pass the same value used in an upstream
    ///     `mwCornerRadius` so the stroke hugs the rounded clip.
    /// - Returns: A view overlaid with the configured stroke.
    func mwStroke(
        color: Color = MWColor.ink,
        width: CGFloat = MWBorder.defaultWidth,
        cornerRadius: CGFloat = 0
    ) -> some View {
        modifier(MWStroke(color: color, width: width, cornerRadius: cornerRadius))
    }
}
