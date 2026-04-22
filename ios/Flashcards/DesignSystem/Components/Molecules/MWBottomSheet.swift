//
//  MWBottomSheet.swift
//  Flashcards
//
//  Purpose: View modifier + extension presenting a SwiftUI `.sheet` styled to
//           the Modernist palette — paper background, visible drag indicator,
//           caller-controlled detents.
//  Dependencies: SwiftUI, MWColor.
//

import SwiftUI

/// ViewModifier backing the `.mwBottomSheet(...)` extension.
public struct MWBottomSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let detents: Set<PresentationDetent>
    @ViewBuilder let sheetContent: () -> SheetContent

    public func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            sheetContent()
                .presentationDetents(detents)
                .presentationDragIndicator(.visible)
                .presentationBackground(MWColor.paper)
        }
    }
}

public extension View {
    /// Presents a bottom sheet with paper background, drag indicator, and custom detents.
    func mwBottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        modifier(
            MWBottomSheetModifier(
                isPresented: isPresented,
                detents: detents,
                sheetContent: content
            )
        )
    }
}
