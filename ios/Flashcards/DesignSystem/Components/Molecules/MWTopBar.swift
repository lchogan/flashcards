//
//  MWTopBar.swift
//  Flashcards
//
//  Purpose: Page-level top bar with optional leading / trailing view slots and
//           a centred title. Replaces SwiftUI's `.navigationBar` usage where
//           the Modernist layout needs full visual control.
//  Dependencies: SwiftUI, MWColor, MWSpacing, MWType.
//  Key concepts: 44pt min-height matches Apple's HIG hit-target; horizontal
//                padding uses the screen-edge `.l` token.
//

import SwiftUI

/// Top bar with centered title and view-builder leading/trailing slots.
public struct MWTopBar<Leading: View, Trailing: View>: View {
    let title: String?
    let leading: () -> Leading
    let trailing: () -> Trailing

    /// Creates a new instance.
    public init(
        title: String? = nil,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.leading = leading
        self.trailing = trailing
    }

    /// View body.
    public var body: some View {
        HStack {
            leading()
            Spacer()
            if let title {
                Text(title).font(MWType.headingM).foregroundStyle(MWColor.ink)
            }
            Spacer()
            trailing()
        }
        .frame(minHeight: 44)
        .mwPadding(.horizontal, .l)
    }
}

#Preview("MWTopBar") {
    MWTopBar(
        title: "Deck name",
        leading: { Text("<").font(MWType.headingM) },
        trailing: { Text("•••").font(MWType.headingM) }
    )
    .background(MWColor.canvas)
}
