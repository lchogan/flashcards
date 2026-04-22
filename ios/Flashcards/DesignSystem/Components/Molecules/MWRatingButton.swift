//
//  MWRatingButton.swift
//  Flashcards
//
//  Purpose: Big rating button used at the bottom of a Smart Study session to log
//           a user's Again / Hard / Good / Easy response. Shows the upcoming
//           interval label on a second line.
//  Dependencies: SwiftUI, MWColor, MWSpacing, MWType, MWRadius, MWRating.
//  Key concepts: All four rating tints live in the color palette; selecting the
//                background is a pure mapping from `MWRating`. `size` controls the
//                min-height only — callers keep the HStack full-width.
//

import SwiftUI

/// Tappable rating button with label + next-interval caption.
public struct MWRatingButton: View {
    /// Size.
    public enum Size { case regular, compact }

    let rating: MWRating
    let intervalLabel: String
    let action: () -> Void
    let size: Size

    /// - Parameters:
    ///   - rating: Which MWRating to log.
    ///   - intervalLabel: Display string for the upcoming interval (e.g. "6m", "4d").
    ///   - size: Vertical scale. Regular is 72pt min-height, compact is 56pt.
    ///   - action: Callback invoked on tap.
    public init(
        rating: MWRating,
        intervalLabel: String,
        size: Size = .regular,
        action: @escaping () -> Void
    ) {
        self.rating = rating
        self.intervalLabel = intervalLabel
        self.size = size
        self.action = action
    }

    /// View body.
    public var body: some View {
        Button(action: action) {
            VStack(spacing: MWSpacing.xs) {
                Text(rating.label).font(MWType.bodyL.weight(.semibold))
                Text(intervalLabel).font(MWType.bodyS)
            }
            .foregroundStyle(MWColor.paper)
            .frame(maxWidth: .infinity, minHeight: size == .regular ? 72 : 56)
            .background(tint)
            .mwCornerRadius(.s)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(rating.label)
        .accessibilityIdentifier(rating.label)
    }

    private var tint: Color {
        switch rating {
        case .again: MWColor.again
        case .hard: MWColor.hard
        case .good: MWColor.good
        case .easy: MWColor.easy
        }
    }
}

#Preview("Rating buttons row") {
    HStack(spacing: MWSpacing.s) {
        MWRatingButton(rating: .again, intervalLabel: "6m") {}
        MWRatingButton(rating: .hard, intervalLabel: "1d") {}
        MWRatingButton(rating: .good, intervalLabel: "4d") {}
        MWRatingButton(rating: .easy, intervalLabel: "12d") {}
    }
    .mwPadding(.all, .l)
    .background(MWColor.canvas)
}
