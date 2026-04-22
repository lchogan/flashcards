//
//  MWSection.swift
//  Flashcards
//
//  Purpose: Container grouping a labeled region of content. Renders an optional
//           eyebrow title above a vertical stack of child views.
//  Dependencies: SwiftUI, MWSpacing, MWEyebrow.
//

import SwiftUI

/// Titled container — eyebrow title (optional) above a vertical content stack.
public struct MWSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    /// Creates a new instance.
    public init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    /// View body.
    public var body: some View {
        VStack(alignment: .leading, spacing: MWSpacing.s) {
            if let title { MWEyebrow(title) }
            content()
        }
    }
}

#Preview("MWSection") {
    MWSection("Overview") {
        Text("Body content here")
    }
    .mwPadding(.all, .l)
    .background(MWColor.canvas)
}
