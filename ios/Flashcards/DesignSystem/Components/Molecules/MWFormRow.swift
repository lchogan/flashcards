//
//  MWFormRow.swift
//  Flashcards
//
//  Purpose: Settings-style row with a leading title, trailing value, optional
//           accessory view (chevron, switch, etc.) and tap handler.
//  Dependencies: SwiftUI, MWColor, MWSpacing, MWType.
//  Key concepts: `contentShape(Rectangle())` so the whole row is hit-testable
//                even when accessory + value leave visual gaps.
//

import SwiftUI

/// Row that places a title on the leading edge, optional value + accessory on
/// the trailing edge. Tappable if `onTap` is provided.
public struct MWFormRow<Accessory: View>: View {
    let title: String
    let value: String?
    @ViewBuilder let accessory: () -> Accessory
    let onTap: (() -> Void)?

    public init(
        title: String,
        value: String? = nil,
        onTap: (() -> Void)? = nil,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.value = value
        self.accessory = accessory
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            onTap?()
        } label: {
            HStack {
                Text(title).font(MWType.bodyL).foregroundStyle(MWColor.ink)
                Spacer()
                if let value {
                    Text(value).font(MWType.body).foregroundStyle(MWColor.inkMuted)
                }
                accessory()
            }
            .mwPadding(.vertical, .m)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

#Preview("MWFormRow") {
    VStack(spacing: 0) {
        MWFormRow(title: "Notifications", value: "On") {}
        MWDivider()
        MWFormRow(title: "Accent", value: "Moss") {}
    }
    .mwPadding(.all, .l)
    .background(MWColor.canvas)
}
