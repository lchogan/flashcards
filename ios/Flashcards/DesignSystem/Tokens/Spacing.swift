//
//  Spacing.swift
//  Flashcards
//
//  Purpose: 4pt grid spacing scale and the `mwPadding` token-aware modifier
//           that replaces raw `.padding(<literal>)` throughout view code.
//  Dependencies: SwiftUI (View, Edge.Set).
//  Key concepts: Literal padding values are banned by SwiftLint rule
//                `no_literal_padding` (Task 0.12). Every call site goes through
//                `MWSpacingToken` so the scale stays centralized.
//

import SwiftUI

/// 4pt grid spacing scale.
public enum MWSpacing {
    /// 2pt.
    public static let xxs: CGFloat = 2
    /// 4pt.
    public static let xs: CGFloat = 4
    /// 8pt.
    public static let s: CGFloat = 8
    /// 12pt.
    public static let m: CGFloat = 12
    /// 16pt.
    public static let l: CGFloat = 16
    /// 24pt.
    public static let xl: CGFloat = 24
    /// 32pt.
    public static let xxl: CGFloat = 32
    /// 48pt.
    public static let xxxl: CGFloat = 48
}

/// Enumerated spacing steps so view code passes a token (not a raw CGFloat).
public enum MWSpacingToken {
    case xxs, xs, s, m, l, xl, xxl, xxxl

    /// Raw point value for the token. Use `mwPadding` instead when possible.
    public var value: CGFloat {
        switch self {
        case .xxs: return MWSpacing.xxs
        case .xs: return MWSpacing.xs
        case .s: return MWSpacing.s
        case .m: return MWSpacing.m
        case .l: return MWSpacing.l
        case .xl: return MWSpacing.xl
        case .xxl: return MWSpacing.xxl
        case .xxxl: return MWSpacing.xxxl
        }
    }
}

/// Token-aware padding modifier. Replaces `.padding(<literal>)` in all view code
/// (the literal form is banned by SwiftLint rule `no_literal_padding`).
public extension View {
    /// Applies a design-system padding token to the specified edges.
    func mwPadding(_ edges: Edge.Set = .all, _ token: MWSpacingToken) -> some View {
        self.padding(edges, token.value)
    }
}

#Preview("Spacing grid") {
    VStack(alignment: .leading, spacing: MWSpacing.s) {
        ForEach(Array(stride(from: 0, through: 48, by: 4)), id: \.self) { px in
            HStack(spacing: 8) {
                Rectangle().fill(MWColor.ink).frame(width: CGFloat(px), height: 8)
                Text("\(px)pt").font(MWType.mono)
            }
        }
    }
    .mwPadding(.all, .l)
}
