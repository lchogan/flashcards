/// CardEditView.swift
///
/// Modal editor for an existing card: edit front/back, reset FSRS progress, or
/// soft-delete. Closes via dismiss on save/delete.
///
/// Dependencies: SwiftUI, SwiftData, CardFormModel, CardRepository.

import SwiftData
import SwiftUI

struct CardEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let card: CardEntity

    @State private var form: CardFormModel
    @State private var showDelete = false

    init(card: CardEntity) {
        self.card = card
        _form = State(initialValue: CardFormModel(
            frontText: card.frontText,
            backText: card.backText
        ))
    }

    var body: some View {
        NavigationStack {
            MWScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: MWSpacing.l) {
                        MWTextArea(label: "Front", text: $form.frontText)
                        MWTextArea(label: "Back", text: $form.backText)
                        Button("Reset progress") { resetProgress() }
                            .buttonStyle(.mwSecondary)
                        Button("Delete card") { showDelete = true }
                            .buttonStyle(.mwDestructive)
                    }
                    .mwPadding(.all, .xl)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { save() } }
            }
            .confirmationDialog("Delete this card?", isPresented: $showDelete) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func save() {
        try? CardRepository(context: context).update(card) { instance in
            instance.frontText = form.frontText
            instance.backText = form.backText
        }
        dismiss()
    }

    private func resetProgress() {
        try? CardRepository(context: context).resetProgress(card)
        dismiss()
    }

    private func delete() {
        try? CardRepository(context: context).softDelete(card)
        dismiss()
    }
}
