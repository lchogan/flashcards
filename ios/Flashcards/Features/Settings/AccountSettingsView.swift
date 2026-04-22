//
//  AccountSettingsView.swift
//  Flashcards
//
//  Purpose: Account-level actions — sign out + delete account. Delete is a
//           soft schedule on the server (DELETE /v1/me → 30-day grace);
//           after local token clear the RootView routes back to signup.
//  Dependencies: SwiftUI, AppState, TokenStore, APIClient.
//

import SwiftUI

struct AccountSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showingDeleteConfirm = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        MWScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    if case .authenticated(let userId) = appState.authStatus {
                        MWFormRow(title: "User ID", value: userId) {
                            EmptyView()
                        }
                    }

                    MWButton("Sign out", kind: .secondary) {
                        Task { await signOut() }
                    }

                    MWButton("Delete account", kind: .destructive) {
                        showingDeleteConfirm = true
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(MWType.body)
                            .foregroundStyle(MWColor.again)
                    }
                }
                .mwPadding(.all, .xl)
            }
        }
        .navigationTitle("Account")
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete permanently", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All your decks and cards will be removed in 30 days. This cannot be undone.")
        }
    }

    private func signOut() async {
        let tokenStore = TokenStore()
        await tokenStore.clear()
        await MainActor.run {
            appState.authStatus = .unauthenticated
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        let tokenStore = TokenStore()
        let api = APIClient(baseURL: URL(string: "http://localhost:8000")!) {
            await tokenStore.access()
        }
        do {
            _ = try await api.send(
                APIEndpoint<Empty204>(
                    method: "DELETE",
                    path: "/api/v1/me",
                    body: nil,
                    requiresAuth: true
                ))
            await tokenStore.clear()
            await MainActor.run {
                appState.authStatus = .unauthenticated
            }
        } catch {
            errorMessage = "Couldn't delete right now. Try again."
        }
    }
}
