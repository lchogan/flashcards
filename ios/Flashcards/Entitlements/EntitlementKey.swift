//
//  EntitlementKey.swift
//  Flashcards
//
//  Purpose: Canonical identifier for every gate the UI can hit. Wire-compatible
//           with the server's plan matrix; rawValues must match config/plans.php
//           on the Laravel side 1:1.
//  Dependencies: Foundation only.
//  Key concepts: `EntitlementResult` pairs a gate outcome with the triggering
//                reason + limit so the paywall can theme itself.
//

import Foundation

/// Stable identifiers for every gate the app enforces.
///
/// Rawvalues MUST match `config/plans.php` and the entitlement keys emitted by
/// `GET /v1/me/entitlements`. Adding a new entitlement: add a case here *and*
/// a row on the server config — out-of-sync keys silently deny in the client.
internal enum EntitlementKey: String, Codable, CaseIterable, Identifiable, Sendable {
    case decksCreate = "decks.create"
    case cardsCreateInDeck = "cards.create_in_deck"
    case cardsCreateTotal = "cards.create_total"
    case studySmart = "study.smart"
    case studyBasic = "study.basic"
    case remindersAdd = "reminders.add"
    case newCardLimitAbove10 = "new_card_limit.above_10"
    case fsrsPersonalized = "fsrs.personalized"
    case imagesUse = "images.use"
    case importCsv = "import.csv"
    case exportCsv = "export.csv"
    case exportJson = "export.json"

    internal var id: String { rawValue }
}

/// Outcome of an `EntitlementsManager.can(_:)` check.
internal struct EntitlementResult: Equatable, Sendable {
    internal enum Outcome: Equatable, Sendable {
        case allowed
        case paywall(reason: EntitlementKey, limit: Int?)
    }

    internal let outcome: Outcome

    internal var allowed: Bool {
        if case .allowed = outcome {
            return true
        }
        return false
    }

    internal init(outcome: Outcome) {
        self.outcome = outcome
    }
}
