//
//  MWIcon.swift
//  Flashcards
//
//  Purpose: Named icon registry. Each icon is a stroke-only SwiftUI `Shape` or
//           lightweight `View` living in `Generated/`. `MWIcon` wraps them in a
//           size-aware frame so callers use named tokens instead of paths.
//  Dependencies: SwiftUI, icon structs in Generated/.
//  Key concepts: The generation story is tracked in `scripts/generate-icons.sh`;
//                icons are hand-authored for v1 (no real SVG pipeline yet), but
//                the enum-driven switch keeps the public API stable when the
//                generator lands.
//

import SwiftUI

/// Enum of registered icon names. Each case maps to a struct in `Generated/`.
public enum MWIconName: String, CaseIterable {
    case home, search, settings, add, delete, back, more, check, close, chevronRight
}

/// Renders a named icon at the requested square size.
public struct MWIcon: View {
    let name: MWIconName
    let size: CGFloat

    public init(_ name: MWIconName, size: CGFloat = 20) {
        self.name = name
        self.size = size
    }

    public var body: some View {
        switch name {
        case .home: HomeIcon().frame(width: size, height: size)
        case .search: SearchIcon().frame(width: size, height: size)
        case .settings: SettingsIcon().frame(width: size, height: size)
        case .add: AddIcon().frame(width: size, height: size)
        case .delete: DeleteIcon().frame(width: size, height: size)
        case .back: BackIcon().frame(width: size, height: size)
        case .more: MoreIcon().frame(width: size, height: size)
        case .check: CheckIcon().frame(width: size, height: size)
        case .close: CloseIcon().frame(width: size, height: size)
        case .chevronRight: ChevronRightIcon().frame(width: size, height: size)
        }
    }
}

#Preview("All icons") {
    let columns = [GridItem(.adaptive(minimum: 56, maximum: 72))]
    return LazyVGrid(columns: columns, spacing: MWSpacing.l) {
        ForEach(MWIconName.allCases, id: \.self) { name in
            VStack(spacing: MWSpacing.xs) {
                MWIcon(name, size: 28)
                Text(name.rawValue).font(MWType.bodyS).foregroundStyle(MWColor.inkMuted)
            }
        }
    }
    .mwPadding(.all, .l)
    .background(MWColor.canvas)
}
