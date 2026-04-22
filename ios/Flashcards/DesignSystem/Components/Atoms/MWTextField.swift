//
//  MWTextField.swift
//  Flashcards
//
//  Purpose: Modernist single-line text input atom. Renders an uppercase eyebrow
//           label above a bordered `TextField`, wired to a `@Binding<String>`
//           and optionally configured with a `UITextContentType` (autofill) and
//           `UIKeyboardType` (keyboard layout). Intended for onboarding / auth
//           fields such as email, username, etc.
//  Dependencies: SwiftUI (View, TextField, Binding), UIKit (UITextContentType,
//                UIKeyboardType — these are UIKit types and are not re-exported
//                by SwiftUI), `MWSpacing` / `MWSpacingToken` (`mwPadding`),
//                `MWRadius` / `MWRadiusToken` (`mwCornerRadius`), `MWColor`,
//                `MWType`, `mwStroke` (Borders.swift).
//  Key concepts: Defaults `.textInputAutocapitalization(.never)` and
//                `.autocorrectionDisabled()` — sensible for email/username,
//                which is the only current use site (onboarding). Future
//                variants (secure, numeric, multiline) will land as separate
//                atoms or parameterized forms once we have concrete call sites.
//                The overlay stroke is paired with a matching `cornerRadius`
//                so the border traces the rounded clip instead of a sharp
//                rectangle (same pattern as MWCard and MWSecondaryButtonStyle).
//

import SwiftUI
import UIKit

/// Single-line text input atom with an uppercase eyebrow label and a bordered field.
/// Binds to a `String` and accepts optional `UITextContentType` (for autofill) and
/// `UIKeyboardType` (for keyboard layout). Autocapitalization and autocorrection are
/// disabled — appropriate for the current onboarding email/username use case.
public struct MWTextField: View {
    let label: String
    @Binding var text: String
    let contentType: UITextContentType?
    let keyboard: UIKeyboardType

    /// Creates a labelled text field bound to a `String`.
    /// - Parameters:
    ///   - label: Eyebrow label rendered above the field in uppercase `MWType.eyebrow`.
    ///   - text: Binding to the underlying string value.
    ///   - contentType: Optional `UITextContentType` to drive system autofill
    ///     (e.g. `.emailAddress`, `.username`). Defaults to `nil`.
    ///   - keyboard: Keyboard layout to present. Defaults to `.default`.
    public init(
        label: String,
        text: Binding<String>,
        contentType: UITextContentType? = nil,
        keyboard: UIKeyboardType = .default
    ) {
        self.label = label
        self._text = text
        self.contentType = contentType
        self.keyboard = keyboard
    }

    /// Renders the eyebrow label stacked above a bordered, rounded `TextField`.
    public var body: some View {
        VStack(alignment: .leading, spacing: MWSpacing.xs) {
            Text(label)
                .font(MWType.eyebrow).tracking(MWType.eyebrowTracking)
                .foregroundStyle(MWColor.inkMuted)

            TextField("", text: $text)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(MWType.bodyL).foregroundStyle(MWColor.ink)
                .mwPadding(.all, .m)
                .background(MWColor.paper)
                .mwCornerRadius(.s)
                .mwStroke(cornerRadius: MWRadius.s)
        }
    }
}

#Preview("MWTextField") {
    StatefulPreviewWrapper("") { binding in
        MWTextField(label: "Email", text: binding, contentType: .emailAddress, keyboard: .emailAddress)
            .mwPadding(.all, .xl)
            .background(MWColor.canvas)
    }
}

/// Preview helper — allows mutable state in `#Preview` blocks so atoms that take
/// a `Binding<Value>` can be exercised live. General-purpose across the design
/// system; intentionally `public` so future atoms (toggles, search fields, etc.)
/// can reuse it from their own previews.
public struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    let content: (Binding<Value>) -> Content

    /// Creates a preview wrapper seeded with `initial` and rendering `content`
    /// with a live `Binding` to the wrapped state.
    /// - Parameters:
    ///   - initial: Starting value for the wrapped `@State`.
    ///   - content: View builder invoked with a `Binding<Value>` to the state.
    public init(_ initial: Value, @ViewBuilder _ content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }

    /// Passes the live binding through to the caller-supplied content closure.
    public var body: some View { content($value) }
}
