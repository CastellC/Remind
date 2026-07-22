import SwiftUI
import SwiftData

struct MeaningfulDateSettingsView: View {
    @Environment(AppContainer.self) private var container
    @Query(sort: \MeaningfulDateReminder.date) private var reminders: [MeaningfulDateReminder]
    @Query(sort: \EvidenceEntry.updatedAt, order: .reverse) private var entries: [EvidenceEntry]

    @State private var selectedEntryID: UUID?
    @State private var date = Date()
    @State private var recurrence: DateRecurrence = .yearly
    @State private var label = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Picker(
                    String(localized: "meaningful.entry", defaultValue: "Evidence item"),
                    selection: $selectedEntryID
                ) {
                    Text(String(localized: "meaningful.choose", defaultValue: "Choose…")).tag(Optional<UUID>.none)
                    ForEach(entries.filter { !$0.isArchived && $0.deletedAt == nil }, id: \.id) { entry in
                        Text(entry.title).tag(Optional(entry.id))
                    }
                }
                DatePicker(
                    String(localized: "meaningful.date", defaultValue: "Date"),
                    selection: $date,
                    displayedComponents: .date
                )
                Picker(String(localized: "meaningful.recurrence", defaultValue: "Recurrence"), selection: $recurrence) {
                    ForEach(DateRecurrence.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                TextField(
                    String(localized: "meaningful.label", defaultValue: "Label (optional)"),
                    text: $label
                )
                PrimaryButton(
                    title: String(localized: "meaningful.add", defaultValue: "Add reminder"),
                    isEnabled: selectedEntryID != nil
                ) {
                    Task { await add() }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text(String(localized: "meaningful.explain.title", defaultValue: "Meaningful dates"))
            } footer: {
                Text(
                    String(
                        localized: "meaningful.explain",
                        defaultValue: "Remind me around this date. Evidence does not invent “on this day” memories."
                    )
                )
            }

            Section(String(localized: "meaningful.existing", defaultValue: "Existing reminders")) {
                if reminders.isEmpty {
                    Text(String(localized: "meaningful.empty", defaultValue: "No meaningful-date reminders yet."))
                        .foregroundStyle(EvidenceFallbackColors.muted)
                } else {
                    ForEach(reminders, id: \.id) { reminder in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reminder.displayLabel)
                                .font(.evidenceBody().weight(.medium))
                            Text(reminder.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.evidenceCaption())
                                .foregroundStyle(EvidenceFallbackColors.muted)
                            Text(reminder.recurrence.displayName)
                                .font(.evidenceCaption())
                                .foregroundStyle(EvidenceFallbackColors.muted)
                            Toggle(
                                String(localized: "meaningful.enabled", defaultValue: "Enabled"),
                                isOn: Binding(
                                    get: { reminder.enabled },
                                    set: { newValue in
                                        reminder.enabled = newValue
                                        reminder.touch()
                                        Task { try? await container.meaningfulDateRepository.save(reminder) }
                                    }
                                )
                            )
                        }
                    }
                    .onDelete(perform: delete)
                }
            }

            if let message {
                Section {
                    Text(message)
                        .font(.evidenceCaption())
                        .foregroundStyle(EvidenceFallbackColors.muted)
                }
            }
        }
        .navigationTitle(String(localized: "meaningful.nav", defaultValue: "Meaningful dates"))
    }

    private func add() async {
        guard let selectedEntryID,
              let entry = entries.first(where: { $0.id == selectedEntryID }) else { return }
        let reminder = MeaningfulDateReminder(
            entry: entry,
            date: date,
            recurrence: recurrence,
            enabled: true,
            label: label.isEmpty ? nil : label
        )
        entry.meaningfulDate = date
        entry.touch()
        try? await container.entryRepository.save(entry)
        try? await container.meaningfulDateRepository.save(reminder)
        label = ""
        message = String(localized: "meaningful.saved", defaultValue: "Reminder saved.")
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let reminder = reminders[index]
            Task { try? await container.meaningfulDateRepository.delete(id: reminder.id) }
        }
    }
}
