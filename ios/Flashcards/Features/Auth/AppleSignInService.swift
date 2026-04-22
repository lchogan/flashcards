//
//  AppleSignInService.swift
//  Flashcards
//
//  Purpose: Thin async wrapper around `ASAuthorizationController` that
//           presents the system Sign in with Apple sheet and returns the
//           resulting identity token + user metadata, or throws the
//           framework's error unchanged.
//  Dependencies: AuthenticationServices (ASAuthorizationController,
//                ASAuthorizationAppleIDProvider), UIKit (UIApplication /
//                UIWindowScene via SwiftUI).
//  Key concepts: The Authentication Services API is delegate-based. We
//                bridge it to `async` with a single `CheckedContinuation`
//                stored as a mutable property on the service, resumed by
//                the delegate callbacks. Because that continuation is
//                mutable state shared between `signIn()` and the delegate
//                methods, the whole class is `@MainActor`-isolated —
//                UIKit already dispatches Authentication Services
//                callbacks on the main queue, so this matches reality and
//                satisfies Swift 6 strict concurrency. Each call to
//                `signIn()` replaces any in-flight continuation; callers
//                are expected to await completion before starting another
//                flow.
//

import AuthenticationServices
import SwiftUI

/// Immutable result of a successful Sign in with Apple flow.
///
/// - `identityToken`: JWT the backend uses to verify the user against
///   Apple's public keys (`POST /api/v1/auth/apple`).
/// - `userIdentifier`: The stable `sub` Apple returns for this user;
///   stored server-side so a re-authentication can find the existing
///   account.
/// - `email`: Apple returns an email only on the very first sign-in;
///   `nil` on every subsequent attempt. Persist it server-side when
///   present and fall back to the stored value otherwise.
/// - `fullName`: First + last name components, also only populated on
///   the first sign-in.
public struct AppleIdentity: Sendable, Equatable {
    /// JWT identity token the backend verifies against Apple's JWKS.
    public let identityToken: String
    /// Stable Apple user id (`sub` claim). Safe to persist server-side.
    public let userIdentifier: String
    /// Email address — present only on first sign-in, `nil` thereafter.
    public let email: String?
    /// Name components — present only on first sign-in, `nil` thereafter.
    public let fullName: PersonNameComponents?

    /// Equatability is structural; `PersonNameComponents` conforms to
    /// `Equatable` in Foundation, so the synthesised implementation is
    /// fine for our use cases (unit-test assertions).
    public init(
        identityToken: String,
        userIdentifier: String,
        email: String?,
        fullName: PersonNameComponents?
    ) {
        self.identityToken = identityToken
        self.userIdentifier = userIdentifier
        self.email = email
        self.fullName = fullName
    }
}

/// Presents the system Sign in with Apple sheet and returns the result.
///
/// Instances are cheap to create and are not thread-safe beyond the
/// MainActor isolation that serialises access for us. Typical usage:
///
/// ```swift
/// let service = AppleSignInService()
/// let identity = try await service.signIn()
/// ```
///
/// A second call while a sign-in is in progress will overwrite the
/// stored continuation and leak the previous one; `AuthManager` never
/// does this, and other callers shouldn't either.
@MainActor
public final class AppleSignInService:
    NSObject,
    ObservableObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    /// Pending continuation for the in-flight `signIn()` call. Lives on
    /// the instance because the delegate callbacks can't capture it
    /// directly. Cleared the moment it is resumed.
    private var continuation: CheckedContinuation<AppleIdentity, Error>?

    /// Creates a new service. No side effects — the ASAuthorization
    /// controller is built fresh on every `signIn()` call.
    public override init() {
        super.init()
    }

    /// Presents the system sign-in sheet and suspends until the user
    /// completes or cancels.
    ///
    /// - Returns: `AppleIdentity` on success.
    /// - Throws: The raw `Error` produced by `ASAuthorizationController`
    ///   (typically `ASAuthorizationError.canceled` when the user
    ///   dismisses the sheet), or `URLError(.badServerResponse)` if
    ///   Apple returns a credential missing an identity token.
    public func signIn() async throws -> AppleIdentity {
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email, .fullName]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    /// Picks a `UIWindow` to anchor the sign-in sheet on. Falls back to
    /// a fresh `ASPresentationAnchor()` if there is no active key window
    /// — that path should never hit in practice because the app is
    /// foregrounded whenever the user taps "Sign in with Apple".
    public nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first ?? ASPresentationAnchor()
        }
    }

    /// Delegate callback on success. Extracts the identity token and
    /// user metadata and resumes the pending continuation.
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = cred.identityToken,
            let token = String(data: tokenData, encoding: .utf8)
        else {
            continuation?.resume(throwing: URLError(.badServerResponse))
            continuation = nil
            return
        }
        continuation?.resume(
            returning: AppleIdentity(
                identityToken: token,
                userIdentifier: cred.user,
                email: cred.email,
                fullName: cred.fullName
            )
        )
        continuation = nil
    }

    /// Delegate callback on failure. Forwards the error unchanged.
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
