import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @Environment(AppContainer.self) private var container
    @Query(sort: \CategoryModel.sortOrder) private var categories: [CategoryModel]

    @State private var newName = ""
    @State private var editing: CategoryModel?
    @State private var editName = ""
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                HStack {
                    TextField(
                        String(localized: "categories.new", defaultValue: "New category name"),
                        text: $newName
                    )
                    Button(String(localized: "action.add", defaultValue: "Add")) {
                        Task { await addCategory() }
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section(String(localized: "categories.list", defaultValue: "Your categories")) {
                ForEach(categories, id: \.id) { category in
                    HStack {
                        if let icon = category.iconName {
                            Image(systemName: icon)
                                .foregroundStyle(EvidenceFallbackColors.accent)
                                .accessibilityHidden(true)
                        }
                        Text(category.name)
                        Spacer()
                        Button(String(localized: "action.edit", defaultValue: "Edit")) {
                            editing = category
                            editName = category.name
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                .onDelete(perform: delete)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.evidenceCaption())
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle(String(localized: "categories.nav", defaultValue: "Categories"))
        .alert(
            String(localized: "categories.rename", defaultValue: "Rename category"),
            isPresented: Binding(
                get: { editing != nil },
                set: { if !$0 { editing = nil } }
            )
        ) {
            TextField(String(localized: "categories.name", defaultValue: "Name"), text: $editName)
            Button(String(localized: "action.save", defaultValue: "Save")) {
                Task { await rename() }
            }
            Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {
                editing = nil
            }
        }
    }

    private func addCategory() async {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let category = CategoryModel(
            name: name,
            iconName: "folder",
            sortOrder: (categories.map(\.sortOrder).max() ?? -1) + 1
        )
        do {
            try await container.categoryRepository.save(category)
            newName = ""
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "categories.error", defaultValue: "Could not save the category.")
        }
    }

    private func rename() async {
        guard let editing else { return }
        let name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        editing.name = name
        editing.touch()
        try? await container.categoryRepository.save(editing)
        self.editing = nil
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let category = categories[index]
            Task {
                try? await container.categoryRepository.delete(id: category.id)
            }
        }
    }
}
