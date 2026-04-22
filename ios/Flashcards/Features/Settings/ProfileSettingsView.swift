//
//  ProfileSettingsView.swift
//  Flashcards
//
//  Purpose: Edit the user's display name. Sends PATCH /v1/me on save.
//  Dependencies: SwiftUI, APIClient, TokenStore.
//

import SwiftUI

struct ProfileSettingsView: View {
    @State private var name: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedSuccessfully = false

    var body: some View {
        MWScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    MWTextField(label: "Name", text: $name)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(MWType.body)
                            .foregroundStyle(MWColor.again)
                    }

                    if savedSuccessfully {
                        Text("Saved.")
                            .font(MWType.body)
                            .foregroundStyle(MWColor.inkMuted)
                    }

                    MWButton("Save") {
                        Task { await save() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
                .mwPadding(.all, .xl)
            }
        }
        .navigationTitle("Profile")
        .task { await load() }
    }

    private func load() async {
        let tokenStore = TokenStore()
        let api = APIClient(baseURL: URL(string: "http://localhost:8000")!) {
            await tokenStore.access()
        }
        struct MeResponse: Decodable {
            let name: String?
        }
        if let me: MeResponse = try? await api.send(
            APIEndpoint<MeResponse>(
                method: "GET",
                path: "/api/v1/me",
                body: nil,
                requiresAuth: true,
            ))
        {
            name = me.name ?? ""
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        savedSuccessfully = false
        defer { isSaving = false }

        let tokenStore = TokenStore()
        let api = APIClient(baseURL: URL(string: "http://localhost:8000")!) {
            await tokenStore.access()
        }

        struct Body: Encodable { let name: String }
        struct Resp: Decodable { let name: String? }
        guard let body = try? JSONEncoder.api.encode(Body(name: name)) else {
            errorMessage = "Couldn't encode."
            return
        }

        do {
            _ = try await api.send(
                APIEndpoint<Resp>(
                    method: "PATCH",
                    path: "/api/v1/me",
                    body: body,
                    requiresAuth: true,
                ))
            savedSuccessfully = true
        } catch {
            errorMessage = "Save failed. Try again."
        }
    }
}
