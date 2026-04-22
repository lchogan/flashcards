/// CardFormModel.swift
///
/// Observable form state shared by CreateCardView and CardEditView. Tracks
/// front / back text and selected sub-topic ids; exposes `isValid` and
/// `hasChanges` for CTA enablement + discard-confirm gating.
///
/// Dependencies: Foundation, Observation.

import Foundation
import Observation

/// CardFormModel.
@MainActor
@Observable
public final class CardFormModel {
    /// frontText.
    public var frontText: String
    /// backText.
    public var backText: String
    /// selectedSubTopicIds.
    public var selectedSubTopicIds: Set<String>

    /// Creates a new instance.
    public init(
        frontText: String = "",
        backText: String = "",
        selectedSubTopicIds: Set<String> = []
    ) {
        self.frontText = frontText
        self.backText = backText
        self.selectedSubTopicIds = selectedSubTopicIds
    }

    /// isValid.
    public var isValid: Bool {
        !frontText.trimmingCharacters(in: .whitespaces).isEmpty
            && !backText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// hasChanges.
    public var hasChanges: Bool {
        !frontText.isEmpty || !backText.isEmpty || !selectedSubTopicIds.isEmpty
    }
}
