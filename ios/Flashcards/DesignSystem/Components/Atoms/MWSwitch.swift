//
//  MWSwitch.swift
//  Flashcards
//
//  Purpose: Design-system wrapper around SwiftUI `Toggle` that enforces the
//           Modernist ink tint and hides labels (rows supply their own).
//  Dependencies: SwiftUI, MWColor.
//

import SwiftUI

/// Boolean binding toggle styled in the Modernist ink tint.
public struct MWSwitch: View {
    @Binding var isOn: Bool

    public init(isOn: Binding<Bool>) { self._isOn = isOn }

    public var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .tint(MWColor.ink)
    }
}

#Preview("MWSwitch") {
    @Previewable @State var on = true
    return MWSwitch(isOn: $on)
        .mwPadding(.all, .l)
        .background(MWColor.canvas)
}
