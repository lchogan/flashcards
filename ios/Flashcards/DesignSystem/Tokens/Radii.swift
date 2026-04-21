//
//  Radii.swift
//  Flashcards
//
//  Purpose: Corner-radius tokens and the `mwCornerRadius` token-aware modifier.
//  Dependencies: SwiftUI (View).
//  Key concepts: The Modernist scale keeps radii small (0–16pt). View code
//                should always pass an `MWRadiusToken` instead of a raw value.
//

import SwiftUI

/// Corner-radius scale.
public enum MWRadius {
    /// 2pt.
    public static let xs: CGFloat = 2
    /// 4pt.
    public static let s: CGFloat = 4
    /// 8pt.
    public static let m: CGFloat = 8
    /// 16pt.
    public static let l: CGFloat = 16
}

/// Enumerated radius steps so view code passes a token (not a raw CGFloat).
public enum MWRadiusToken {
    case xs, s, m, l

    /// Raw point value for the token.
    public var value: CGFloat {
        switch self {
        case .xs: return MWRadius.xs
        case .s: return MWRadius.s
        case .m: return MWRadius.m
        case .l: return MWRadius.l
        }
    }
}

public extension View {
    /// Applies a design-system corner radius by token.
    func mwCornerRadius(_ token: MWRadiusToken) -> some View {
        self.cornerRadius(token.value)
    }
}
