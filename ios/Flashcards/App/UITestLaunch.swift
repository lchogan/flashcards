/// UITestLaunch.swift
///
/// Debug-only launch-argument probe. XCUITest passes flags like
/// `-uiTestFreshInstall true` + `-offlineMode true` which short-circuit
/// onboarding and auth so the test can drive the app deterministically.
///
/// Dependencies: Foundation.
/// Key concepts: Guarded by `#if DEBUG` so release builds never honour test
/// launch args. The handling is additive — production paths are untouched.

import Foundation

/// UITestLaunch.
public enum UITestLaunch {
    /// True when the test harness requested a clean start with a stubbed
    /// auth identity. Release builds always return false.
    public static var isActive: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-uiTestFreshInstall")
            && ProcessInfo.processInfo.arguments.contains("true")
        #else
        return false
        #endif
    }

    /// Stub user id injected when `isActive` is true.
    public static let stubUserId = "ui-test-user"
}
