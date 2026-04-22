//
//  Control.swift
//  Flashcards
//
//  Purpose: Geometry tokens for interactive controls (buttons, fields, chips).
//           Centralizes the minimum-height targets so visual consistency and
//           HIG tap-target compliance stay one edit away.
//  Dependencies: CoreGraphics (CGFloat).
//  Key concepts: Two heights today: `.primary` (52pt — dominant CTAs with
//                enclosing shape) and `.compact` (44pt — HIG minimum, used
//                for text-link-style destructive actions and inline controls).
//                Future chip/field heights will land here as they're needed.
//

import CoreGraphics

/// Geometry tokens for interactive controls.
public enum MWControl {
    /// Minimum height tokens for interactive controls.
    public enum Height {
        /// 52pt. Dominant enclosed CTAs (primary, secondary).
        public static let primary: CGFloat = 52
        /// 44pt. HIG-minimum compact control (destructive text button, inline).
        public static let compact: CGFloat = 44
    }
}
