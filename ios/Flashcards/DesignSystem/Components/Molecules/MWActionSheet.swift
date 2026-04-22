//
//  MWActionSheet.swift
//  Flashcards
//
//  Purpose: Confirmation-dialog-backed action list used for per-row contextual
//           menus (duplicate / move / delete, etc.). Consumers pass a flat list
//           of `MWActionSheetAction` — Cancel is appended automatically.
//  Dependencies: SwiftUI.
//

import SwiftUI

/// A single action inside an MWActionSheet. `role: .destructive` applies SwiftUI's
/// red-tinted treatment.
public struct MWActionSheetAction: Identifiable {
    /// Stable identifier.
    public let id = UUID()
    let label: String
    let role: ButtonRole?
    let action: () -> Void

    /// Creates a new instance.
    public init(_ label: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.label = label
        self.role = role
        self.action = action
    }
}

public extension View {
    /// Presents a SwiftUI confirmation dialog with the given actions + Cancel.
    func mwActionSheet(
        title: String,
        isPresented: Binding<Bool>,
        actions: [MWActionSheetAction]
    ) -> some View {
        confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            ForEach(actions) { action in
                Button(action.label, role: action.role, action: action.action)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
