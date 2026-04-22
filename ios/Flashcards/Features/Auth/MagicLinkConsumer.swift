//
//  MagicLinkConsumer.swift
//  Flashcards
//
//  Purpose: Extract a magic-link token from a universal-link URL of the
//           form `https://flashcards.app/auth/consume?t={token}` and
//           expose the `Notification.Name` used to fan the token out
//           from the `App`-level `.onOpenURL` handler to `RootView`'s
//           observer task.
//  Dependencies: Foundation (`URL`, `URLComponents`, `Notification.Name`).
//  Key concepts: Pure value-level parsing — `extractToken(from:)` is a
//                stateless function on an empty-enum namespace so it is
//                trivially Sendable and unit-testable. The notification
//                name lives alongside the parser to keep the universal-
//                link surface area co-located; producers post to it from
//                `FlashcardsApp`, and consumers (`RootView`) observe it
//                and hand the token to `AuthManager.consumeMagicLink`.
//

import Foundation

/// Namespace for magic-link URL parsing. Empty enum so it cannot be
/// instantiated — all API is static.
public enum MagicLinkConsumer {
    /// Extracts the magic-link token from a universal-link URL.
    ///
    /// Accepts any URL whose path ends with `/auth/consume` and returns
    /// the value of its `t` query parameter, if present.
    ///
    /// - Parameter url: The URL delivered by `onOpenURL` (typically the
    ///   HTTPS universal link the user tapped in Mail / Messages).
    /// - Returns: The token string, or `nil` if the URL does not match
    ///   the consume path or is missing the `t` query item.
    public static func extractToken(from url: URL) -> String? {
        guard
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
            comps.path.hasSuffix("/auth/consume")
        else {
            return nil
        }
        return comps.queryItems?.first(where: { $0.name == "t" })?.value
    }
}

public extension Notification.Name {
    /// Posted by `FlashcardsApp`'s `.onOpenURL` handler when a universal
    /// link carrying a magic-link token is opened. The notification's
    /// `object` is the `String` token; `RootView` observes this and
    /// forwards to `AuthManager.consumeMagicLink(token:)`.
    static let mwMagicLinkToken = Notification.Name("mw.magicLinkToken")
}
