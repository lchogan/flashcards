//
//  Motion.swift
//  Flashcards
//
//  Purpose: Animation tokens. Centralizes every duration and spring curve used
//           in the app so motion stays coherent across components.
//  Dependencies: SwiftUI (Animation).
//  Key concepts: Always resolve animations through `MWMotion.respecting(_:reduceMotion:)`
//                at the call site, passing the `@Environment(\.accessibilityReduceMotion)`
//                value — that collapses motion to an instantaneous linear animation when
//                the user has Reduce Motion enabled.
//

import SwiftUI

/// Animation tokens.
public enum MWMotion {
    /// 120ms ease-out. Micro-interactions (chip press, checkmark).
    public static let instant = Animation.easeOut(duration: 0.12)
    /// 220ms ease-in-out. Short hovers, reveals.
    public static let quick = Animation.easeInOut(duration: 0.22)
    /// Default spring. Most screen transitions.
    public static let standard = Animation.spring(response: 0.32, dampingFraction: 0.85)
    /// Looser spring. Card flips, drawer reveals.
    public static let card = Animation.spring(response: 0.42, dampingFraction: 0.78)
    /// 560ms ease-in-out. Settling animations after heavy movement.
    public static let settled = Animation.easeInOut(duration: 0.56)

    /// Resolves to `.linear(duration: 0)` when Reduce Motion is on.
    public static func respecting(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0) : animation
    }
}
