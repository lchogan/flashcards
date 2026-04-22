//
//  SignUpWallView.swift
//  Flashcards
//
//  Purpose: Post-intro sign-up gate. Offers Sign in with Apple as the
//           primary path and a magic-link email fallback as the
//           secondary. Captures an optional marketing opt-in toggle for
//           a future mailing list (off by default — nothing is sent
//           yet).
//  Dependencies: SwiftUI (ScrollView, VStack, Toggle, State, Binding),
//                `MWScreen`, `MWEyebrow`, `MWButton`, `MWTextField`,
//                `MWSpacing` / `MWSpacingToken`, `MWType`, `MWColor`.
//  Key concepts: Pure presentation over two async closures — the view
//                owns the email/opt-in/submission-state locally and
//                hands results off to the caller. Error surfacing is
//                intentionally not wired in Phase 0 (the caller uses
//                `try?` on the auth calls); the `errorText` slot is a
//                hook for the error-handling task that lands later in
//                the plan. `marketingOptIn` is likewise held but not
//                forwarded yet — future task will pass it to the
//                backend alongside the magic-link request.
//

import SwiftUI

/// Sign-up wall shown after the two intro screens. Primary CTA is Sign in with
/// Apple; secondary is a magic-link email form. Both async paths delegate back
/// to the parent router, which owns the `AuthManager`.
struct SignUpWallView: View {
    /// Invoked when the user taps "Continue with Apple". The parent
    /// drives the Apple sheet via `AuthManager.signInWithApple()`.
    let onAppleSignIn: () async -> Void
    /// Invoked when the user taps "Continue with email". The parent
    /// drives `AuthManager.requestMagicLink(email:)` and advances the
    /// step on success.
    let onRequestMagicLink: (String) async -> Void

    @State private var email = ""
    @State private var marketingOptIn = false
    @State private var isSubmitting = false
    // Reserved for the error-surfacing task landing later in the plan;
    // the current call sites swallow errors with `try?` so this stays
    // `nil` in Phase 0. Intentionally kept to avoid churning the view's
    // shape when that task arrives.
    @State private var errorText: String?

    /// Renders the two-path sign-up form (Apple + email) inside a
    /// `ScrollView` so the keyboard doesn't clip the secondary CTA on
    /// small devices.
    var body: some View {
        MWScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    MWEyebrow("Save your progress")
                    Text("No password required.")
                        .font(MWType.headingL).foregroundStyle(MWColor.ink)
                    // swiftlint:disable:next line_length
                    Text("We ask for your email so your flashcards live in your account, not just this device. If you lose your phone, you won't lose a single card.")
                        .font(MWType.bodyL).foregroundStyle(MWColor.inkMuted)

                    MWButton("Continue with Apple") {
                        Task { isSubmitting = true; await onAppleSignIn(); isSubmitting = false }
                    }

                    MWTextField(label: "Email", text: $email, contentType: .emailAddress, keyboard: .emailAddress)

                    MWButton("Continue with email", kind: .secondary) {
                        Task { isSubmitting = true; await onRequestMagicLink(email); isSubmitting = false }
                    }.disabled(email.isEmpty || isSubmitting)

                    Text("Free to use. No payment needed. We won't sell your data or email you marketing.")
                        .font(MWType.bodyS).foregroundStyle(MWColor.inkFaint)

                    Toggle(isOn: $marketingOptIn) {
                        Text("Send me occasional product updates")
                            .font(MWType.body).foregroundStyle(MWColor.inkMuted)
                    }.tint(MWColor.ink)

                    if let errorText {
                        Text(errorText).font(MWType.body).foregroundStyle(MWColor.again)
                    }
                }.mwPadding(.all, .xl)
            }
        }
    }
}
