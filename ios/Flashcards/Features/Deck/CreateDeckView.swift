/// CreateDeckView.swift
///
/// Bottom-sheet form for creating a new deck. Title + optional description +
/// accent picker + default study mode; calls `onCreated` and dismisses on save.
///
/// Dependencies: SwiftUI, SwiftData, DS Atoms/Molecules, DeckRepository,
/// MWAccent, SessionMode.

import SwiftData
import SwiftUI

struct CreateDeckView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementsManager.self) private var entitlements

    let userId: String
    let onCreated: () -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var accent: MWAccent = .amber
    @State private var mode: SessionMode = .smart
    @State private var paywallReason: EntitlementKey?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MWSpacing.l) {
                MWEyebrow("New deck")
                Text("Create deck").font(MWType.headingL).foregroundStyle(MWColor.ink)

                MWTextField(label: "Title", text: $title)
                MWTextArea(label: "Description (optional)", text: $description, minHeight: 80)

                MWSection("Accent") {
                    HStack(spacing: MWSpacing.s) {
                        ForEach(MWAccent.allCases, id: \.self) { candidate in
                            Button {
                                accent = candidate
                            } label: {
                                Rectangle().fill(candidate.color)
                                    .frame(width: 40, height: 40)
                                    .mwStroke(
                                        color: accent == candidate ? MWColor.ink : MWColor.inkFaint,
                                        width: accent == candidate ? MWBorder.bold : MWBorder.defaultWidth
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                MWSection("Default study mode") {
                    HStack(spacing: MWSpacing.s) {
                        MWChip(text: "Smart (FSRS)", selected: mode == .smart) { mode = .smart }
                        MWChip(text: "Basic", selected: mode == .basic) { mode = .basic }
                    }
                }

                MWButton("Create deck") {
                    attemptCreate()
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .mwPadding(.all, .xl)
        }
        .background(MWColor.canvas)
        .sheet(item: $paywallReason) { reason in
            PaywallView(reason: reason)
        }
    }

    private func attemptCreate() {
        let descriptor = FetchDescriptor<DeckEntity>(
            predicate: #Predicate { $0.syncDeletedAtMs == nil },
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0

        switch entitlements.can(.decksCreate, currentCount: count).outcome {
        case .allowed:
            createDeck()
        case .paywall(let reason, _):
            paywallReason = reason
        }
    }

    private func createDeck() {
        do {
            _ = try DeckRepository(context: context).create(
                title: title,
                accentColor: accent,
                userId: userId,
                defaultStudyMode: mode,
                description: description.isEmpty ? nil : description
            )
            onCreated()
            dismiss()
        } catch {
            AnalyticsClient.track("deck.create.fail")
        }
    }
}
