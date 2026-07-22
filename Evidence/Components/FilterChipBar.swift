import SwiftUI

/// Horizontally scrolling filter chip bar for collection and search filters.
struct FilterChipBar<Item: Identifiable & Hashable>: View {
    let items: [Item]
    @Binding var selection: Set<Item.ID>
    var allowsMultipleSelection: Bool = true
    var titleKey: (Item) -> String
    var symbolName: ((Item) -> String?)? = nil
    var accessibilityHintText: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EvidenceTheme.Spacing.xs) {
                ForEach(items) { item in
                    let isSelected = selection.contains(item.id)
                    TagChip(
                        title: titleKey(item),
                        systemImage: symbolName?(item) ?? nil,
                        isSelected: isSelected,
                        accessibilityHintText: accessibilityHintText ?? selectionHint,
                        onTap: {
                            toggle(item)
                        }
                    )
                }
            }
            .padding(.horizontal, EvidenceTheme.Spacing.md)
            .padding(.vertical, EvidenceTheme.Spacing.xxs)
        }
        .accessibilityElement(children: .contain)
        .evidenceAnimation(EvidenceMotion.selection, value: selection, reduceMotion: reduceMotion)
    }

    private var selectionHint: String {
        allowsMultipleSelection
            ? "Double tap to toggle this filter"
            : "Double tap to apply this filter"
    }

    private func toggle(_ item: Item) {
        if allowsMultipleSelection {
            if selection.contains(item.id) {
                selection.remove(item.id)
            } else {
                selection.insert(item.id)
            }
        } else {
            if selection.contains(item.id) {
                selection.removeAll()
            } else {
                selection = [item.id]
            }
        }
    }
}

/// Convenience bar for `EntryType` filters.
struct EntryTypeFilterChipBar: View {
    @Binding var selection: Set<EntryType>
    var types: [EntryType] = EntryType.allCases

    private struct Wrapper: Identifiable, Hashable {
        let type: EntryType
        var id: EntryType { type }
    }

    private var items: [Wrapper] { types.map(Wrapper.init) }

    private var selectionIDs: Binding<Set<EntryType>> {
        Binding(
            get: { selection },
            set: { selection = $0 }
        )
    }

    var body: some View {
        FilterChipBar(
            items: items,
            selection: selectionIDs,
            allowsMultipleSelection: true,
            titleKey: { $0.type.displayName },
            symbolName: { $0.type.symbolName },
            accessibilityHintText: "Double tap to filter by this entry type"
        )
    }
}

private struct EntryTypeFilterChipBarPreviewHost: View {
    @State private var selected: Set<EntryType> = [.text]

    var body: some View {
        EntryTypeFilterChipBar(selection: $selected)
    }
}

#Preview {
    EntryTypeFilterChipBarPreviewHost()
}
