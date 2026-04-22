/// CardFormModel.swift
///
/// Observable form state shared by CreateCardView and CardEditView. Tracks
/// front / back text and selected sub-topic ids; exposes `isValid` and
/// `hasChanges` for CTA enablement + discard-confirm gating.
///
/// Dependencies: Foundation, Observation.

import Foundation
import Observation

@MainActor
@Observable
public final class CardFormModel {
    public var frontText: String
    public var backText: String
    public var selectedSubTopicIds: Set<String>

    public init(
        frontText: String = "",
        backText: String = "",
        selectedSubTopicIds: Set<String> = []
    ) {
        self.frontText = frontText
        self.backText = backText
        self.selectedSubTopicIds = selectedSubTopicIds
    }

    public var isValid: Bool {
        !frontText.trimmingCharacters(in: .whitespaces).isEmpty &&
        !backText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var hasChanges: Bool {
        !frontText.isEmpty || !backText.isEmpty || !selectedSubTopicIds.isEmpty
    }
}
