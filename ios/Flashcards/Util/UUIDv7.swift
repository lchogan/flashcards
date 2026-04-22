/// UUIDv7.swift
///
/// UUID version 7 generator: 48 bits of Unix-ms timestamp prefix + 74 random bits.
/// Chosen for time-ordered IDs (lexicographic order == insertion order) so that
/// review/session rows cluster naturally on disk and in paginated queries.
///
/// Dependencies: Foundation
/// Key concepts: draft-ietf-uuidrev-rfc4122bis § 5.7.

import Foundation

/// Namespace for UUID v7 generation.
public enum UUIDv7 {
    /// Returns a UUIDv7 string in canonical `8-4-4-4-12` hex form.
    public static func next() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let ms = UInt64(Date().timeIntervalSince1970 * 1000)
        bytes[0] = UInt8((ms >> 40) & 0xFF)
        bytes[1] = UInt8((ms >> 32) & 0xFF)
        bytes[2] = UInt8((ms >> 24) & 0xFF)
        bytes[3] = UInt8((ms >> 16) & 0xFF)
        bytes[4] = UInt8((ms >> 8) & 0xFF)
        bytes[5] = UInt8(ms & 0xFF)
        for i in 6..<16 {
            bytes[i] = UInt8.random(in: 0...255)
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x70  // version 7
        bytes[8] = (bytes[8] & 0x3F) | 0x80  // RFC 4122 variant
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let parts = [
            hex.prefix(8),
            hex.dropFirst(8).prefix(4),
            hex.dropFirst(12).prefix(4),
            hex.dropFirst(16).prefix(4),
            hex.dropFirst(20).prefix(12),
        ]
        return parts.joined(separator: "-")
    }
}
