//
//  FlashcardsApp.swift
//  Flashcards
//
//  Purpose: `@main` entry point. Owns the single `AppState` instance and
//           injects it into the SwiftUI environment before mounting
//           `RootView`.
//  Dependencies: SwiftUI, `AppState`, `RootView`.
//  Key concepts: `AppState` is held via `@State` so SwiftUI owns its
//                lifetime for the life of the scene. `.environment(appState)`
//                publishes it for any descendant to observe. SwiftData is
//                not imported yet — it will be added when the model
//                container lands in a later task.
//

import SwiftUI

@main
struct FlashcardsApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView().environment(appState)
        }
    }
}
