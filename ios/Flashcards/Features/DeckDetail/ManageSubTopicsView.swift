/// ManageSubTopicsView.swift
///
/// Sub-topic management sheet: add, rename-via-edit, delete, reorder. Backed
/// directly by SubTopicRepository.
///
/// Dependencies: SwiftUI, SwiftData, SubTopicRepository, SubTopicEntity,
/// DS Atoms/Molecules.

import SwiftData
import SwiftUI

struct ManageSubTopicsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let deckId: String

    @State private var subTopics: [SubTopicEntity] = []
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            MWScreen {
                List {
                    Section("New") {
                        HStack {
                            TextField("Add sub-topic", text: $newName).font(MWType.bodyL)
                            Button("Add") { addSubTopic() }
                                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    Section("Existing") {
                        ForEach(subTopics, id: \.id) { topic in
                            Text(topic.name).font(MWType.bodyL)
                        }
                        .onDelete(perform: delete)
                        .onMove(perform: move)
                    }
                }
                .toolbar { EditButton() }
                .task { reload() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
        }
    }

    private func reload() {
        subTopics = (try? SubTopicRepository(context: context).list(deckId: deckId)) ?? []
    }

    private func addSubTopic() {
        _ = try? SubTopicRepository(context: context).create(deckId: deckId, name: newName)
        newName = ""
        reload()
    }

    private func delete(_ offsets: IndexSet) {
        let repo = SubTopicRepository(context: context)
        for index in offsets {
            try? repo.softDelete(subTopics[index])
        }
        reload()
    }

    private func move(from source: IndexSet, to destination: Int) {
        subTopics.move(fromOffsets: source, toOffset: destination)
        try? SubTopicRepository(context: context).reorder(subTopics)
    }
}
