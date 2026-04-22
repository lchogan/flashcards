/// Clock.swift
///
/// Thin wrapper around wall-clock time that allows tests to inject a
/// deterministic timestamp without relying on real system time.
///
/// Dependencies: Foundation
/// Key concepts: test-seam via static override closure; production path
/// delegates directly to Date so there is no hidden state in release builds.

import Foundation

/// Provides the current time as milliseconds since the Unix epoch.
///
/// Tests may set `Clock.override` to a closure returning a fixed value before
/// exercising any code that calls `Clock.nowMs()`.  Always clear the override
/// in `tearDown` to avoid leaking state between test cases.
public enum Clock {
    /// When non-nil, `nowMs()` returns the result of this closure instead of
    /// the real wall-clock time.  Intended exclusively for unit-test use.
    ///
    /// `nonisolated(unsafe)` is required by Swift 6 strict concurrency: the
    /// var is mutable global state used only in tests, where the caller is
    /// responsible for setting and clearing it safely (single-threaded setUp /
    /// tearDown).
    public nonisolated(unsafe) static var override: (() -> Int64)?

    /// Returns the current time in milliseconds since the Unix epoch.
    ///
    /// - Returns: Injected test value when `override` is set; real wall-clock
    ///   time otherwise.
    public static func nowMs() -> Int64 {
        override?() ?? Int64(Date().timeIntervalSince1970 * 1000)
    }
}
