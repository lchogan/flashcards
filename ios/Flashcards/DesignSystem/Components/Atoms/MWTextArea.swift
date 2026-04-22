//
//  MWTextArea.swift
//  Flashcards
//
//  Purpose: Multi-line text editor with eyebrow label, matching MWTextField's
//           stroke + paper background.
//  Dependencies: SwiftUI, MWColor, MWSpacing, MWType, MWRadius, MWBorder, MWEyebrow.
//

import SwiftUI

/// Bordered multi-line text input with an uppercase eyebrow label above.
public struct MWTextArea: View {
    let label: String
    @Binding var text: String
    let minHeight: CGFloat

    public init(label: String, text: Binding<String>, minHeight: CGFloat = 120) {
        self.label = label
        self._text = text
        self.minHeight = minHeight
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MWSpacing.xs) {
            MWEyebrow(label)
            TextEditor(text: $text)
                .font(MWType.bodyL)
                .foregroundStyle(MWColor.ink)
                .scrollContentBackground(.hidden)
                .mwPadding(.all, .s)
                .frame(minHeight: minHeight)
                .background(MWColor.paper)
                .mwCornerRadius(.s)
                .mwStroke(color: MWColor.ink, width: MWBorder.defaultWidth, cornerRadius: MWRadius.s)
        }
    }
}

#Preview("MWTextArea") {
    @Previewable @State var value = ""
    return MWTextArea(label: "Notes", text: $value)
        .mwPadding(.all, .l)
        .background(MWColor.canvas)
}
