/// BulkActionsSheet.swift
///
/// Bottom sheet surfacing bulk operations (reset progress, delete) against a
/// selected set of cards. Pure UI — the caller owns the card list and the
/// action closures.
///
/// Dependencies: SwiftUI, DS Atoms/Molecules.

import SwiftUI

struct BulkActionsSheet: View {
    let cardIds: [String]
    let onDelete: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: MWSpacing.l) {
            MWEyebrow("\(cardIds.count) cards selected")
            Text("Bulk actions")
                .font(MWType.headingM)
                .foregroundStyle(MWColor.ink)
            MWButton("Reset progress", kind: .secondary, action: onReset)
            MWButton("Delete", kind: .destructive, action: onDelete)
        }
        .mwPadding(.all, .xl)
        .presentationDetents([.fraction(0.3)])
        .presentationBackground(MWColor.paper)
    }
}
