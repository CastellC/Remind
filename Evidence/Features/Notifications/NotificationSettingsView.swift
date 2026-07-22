import SwiftUI
import SwiftData

struct NotificationSettingsView: View {
    @Environment(AppContainer.self) private var container
    @Query private var profiles: [AppProfile]
    @Query private var schedules: [ReminderSchedule]
    @Query(sort: \CategoryModel.sortOrder) private var categories: [CategoryModel]

    @State private var isEnabled = false
    @State private var deliveryDate = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var frequency: ReminderFrequency = .weekdays
    @State private var previewMode: NotificationPreviewMode = .generic
    @State private var allowedCategoryIDs: Set<UUID> = []
    @State private var statusMessage: String?
    @State private var isSaving = false

    private var profile: AppProfile? { profiles.first }
    private var schedule: ReminderSchedule? { schedules.first }

    var body: some View {
        Form {
            Section(
                footer: Text(String(localized: "notifications.explain", defaultValue: "Evidence asks for permission only when you turn reminders on."))
            ) {
                Toggle(
                    String(localized: "notifications.enable", defaultValue: "Enable reminders"),
                    isOn: $isEnabled
                )
            }

            if isEnabled {
                Section(String(localized: "notifications.schedule", defaultValue: "Schedule")) {
                    DatePicker(
                        String(localized: "notifications.time", defaultValue: "Time"),
                        selection: $deliveryDate,
                        displayedComponents: .hourAndMinute
                    )
                    Picker(String(localized: "notifications.frequency", defaultValue: "Frequency"), selection: $frequency) {
                        ForEach(ReminderFrequency.allCases) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                }

                Section(
                    String(localized: "notifications.preview", defaultValue: "Preview privacy"),
                    footer: Text(String(localized: "notifications.preview.warn", defaultValue: "Title-only and full-content previews may be visible to other people nearby."))
                ) {
                    Picker(String(localized: "notifications.preview.mode", defaultValue: "Preview"), selection: $previewMode) {
                        ForEach(NotificationPreviewMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    Text(previewMode.detailExplanation)
                        .font(.evidenceCaption())
                        .foregroundStyle(EvidenceFallbackColors.muted)
                }

                if !categories.isEmpty {
                    Section(
                        String(localized: "notifications.categories", defaultValue: "Eligible categories"),
                        footer: Text(String(localized: "notifications.categories.footer", defaultValue: "Leave all unchecked to allow every category."))
                    ) {
                        ForEach(categories, id: \.id) { category in
                            Toggle(category.name, isOn: Binding(
                                get: { allowedCategoryIDs.contains(category.id) },
                                set: { on in
                                    if on { allowedCategoryIDs.insert(category.id) }
                                    else { allowedCategoryIDs.remove(category.id) }
                                }
                            ))
                        }
                    }
                }
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.evidenceCaption())
                        .foregroundStyle(EvidenceFallbackColors.muted)
                }
            }

            Section {
                PrimaryButton(
                    title: String(localized: "action.save", defaultValue: "Save"),
                    isLoading: isSaving
                ) {
                    Task { await save() }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(String(localized: "notifications.nav", defaultValue: "Notifications"))
        .task { load() }
    }

    private func load() {
        if let schedule {
            isEnabled = schedule.isEnabled
            frequency = schedule.frequency
            allowedCategoryIDs = Set(schedule.allowedCategoryIDs)
            deliveryDate = Calendar.current.date(
                from: DateComponents(hour: schedule.deliveryHour, minute: schedule.deliveryMinute)
            ) ?? deliveryDate
        }
        previewMode = profile?.notificationPreviewMode ?? .generic
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: deliveryDate)
        let hour = comps.hour ?? 9
        let minute = comps.minute ?? 0

        if isEnabled {
            do {
                let granted = try await container.notifications.requestAuthorization()
                if !granted {
                    statusMessage = String(
                        localized: "notifications.denied",
                        defaultValue: "Notifications are off for Evidence. You can enable them in iOS Settings."
                    )
                    isEnabled = false
                }
            } catch {
                statusMessage = error.localizedDescription
                return
            }
        }

        let schedule = schedule ?? ReminderSchedule()
        schedule.isEnabled = isEnabled
        schedule.deliveryHour = hour
        schedule.deliveryMinute = minute
        schedule.frequency = frequency
        schedule.allowedCategoryIDs = Array(allowedCategoryIDs)
        schedule.genericPreviewOnly = previewMode == .generic
        schedule.touch()
        try? await container.reminderRepository.save(schedule)

        if let existing = profile {
            existing.notificationPreviewMode = previewMode
            existing.touch()
            try? await container.profileRepository.save(existing)
        } else {
            let created = await container.ensureProfile()
            created.notificationPreviewMode = previewMode
            created.touch()
            try? await container.profileRepository.save(created)
        }

        let entries = (try? await container.entryRepository.fetchAll(includeArchived: false)) ?? []
        try? await container.notifications.reschedule(
            from: schedule,
            entries: entries,
            previewMode: previewMode
        )
        statusMessage = String(localized: "notifications.saved", defaultValue: "Reminder settings saved.")
    }
}
