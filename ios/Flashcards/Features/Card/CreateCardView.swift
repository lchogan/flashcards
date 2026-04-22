/// CreateCardView.swift
///
/// Modal form for authoring a new card: front text, back text, optional
/// sub-topic selection. Cancel with unsaved content triggers a discard confirm.
///
/// Dependencies: SwiftUI, SwiftData, CardFormModel, CardRepository,
/// SubTopicRepository, DS Atoms/Molecules.

import SwiftData
import SwiftUI

struct CreateCardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementsManager.self) private var entitlements

    let deckId: String
    let onSaved: () -> Void

    @State private var form = CardFormModel()
    @State private var subTopics: [SubTopicEntity] = []
    @State private var showDiscardConfirm = false
    @State private var paywallReason: EntitlementKey?

    var body: some View {
        NavigationStack {
            MWScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: MWSpacing.l) {
                        MWTextArea(label: "Front", text: $form.frontText)
                        MWTextArea(label: "Back", text: $form.backText)
                        if !subTopics.isEmpty {
                            MWSection("Sub-topics") {
                                SubTopicChipStrip(
                                    items: subTopics,
                                    selected: $form.selectedSubTopicIds
                                )
                            }
                        }
                    }
                    .mwPadding(.all, .xl)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if form.hasChanges {
                            showDiscardConfirm = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!form.isValid)
                }
            }
            .confirmationDialog("Discard changes?", isPresented: $showDiscardConfirm) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .task {
                subTopics = (try? SubTopicRepository(context: context).list(deckId: deckId)) ?? []
            }
            .sheet(item: $paywallReason) { reason in
                PaywallView(reason: reason)
            }
        }
    }

    private func save() {
        let localDeckId = deckId
        let inDeckDescriptor = FetchDescriptor<CardEntity>(
            predicate: #Predicate { $0.deckId == localDeckId && $0.syncDeletedAtMs == nil }
        )
        let totalDescriptor = FetchDescriptor<CardEntity>(
            predicate: #Predicate { $0.syncDeletedAtMs == nil }
        )
        let countInDeck = (try? context.fetchCount(inDeckDescriptor)) ?? 0
        let countTotal = (try? context.fetchCount(totalDescriptor)) ?? 0

        if case .paywall(let reason, _) = entitlements.can(.cardsCreateInDeck, currentCount: countInDeck).outcome {
            paywallReason = reason
            return
        }
        if case .paywall(let reason, _) = entitlements.can(.cardsCreateTotal, currentCount: countTotal).outcome {
            paywallReason = reason
            return
        }

        do {
            _ = try CardRepository(context: context).create(
                deckId: deckId,
                frontText: form.frontText,
                backText: form.backText,
                subTopicIds: Array(form.selectedSubTopicIds)
            )
            onSaved()
            dismiss()
        } catch {
            AnalyticsClient.track("card.create.fail")
        }
    }
}

/// Wrapping strip of selectable sub-topic chips.
struct SubTopicChipStrip: View {
    let items: [SubTopicEntity]
    @Binding var selected: Set<String>

    var body: some View {
        HStack(alignment: .top, spacing: MWSpacing.xs) {
            ForEach(items, id: \.id) { topic in
                MWChip(text: topic.name, selected: selected.contains(topic.id)) {
                    if selected.contains(topic.id) {
                        selected.remove(topic.id)
                    } else {
                        selected.insert(topic.id)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
