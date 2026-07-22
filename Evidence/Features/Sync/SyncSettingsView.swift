import SwiftUI
import SwiftData

struct SyncSettingsView: View {
    @Environment(AppContainer.self) private var container
    @Query private var profiles: [AppProfile]
    @Query(filter: #Predicate<EvidenceEntry> { $0.syncStatusRaw == "conflict" })
    private var conflicts: [EvidenceEntry]

    @State private var message: String?
    @State private var isSyncing = false

    private var profile: AppProfile? { profiles.first }

    var body: some View {
        Form {
            Section {
                AuthenticationStatusView(
                    isAuthenticated: container.authentication.isAuthenticated,
                    cloudSyncEnabled: profile?.cloudSyncEnabled ?? false
                )
            }

            Section(String(localized: "sync.controls", defaultValue: "Sync")) {
                Toggle(
                    String(localized: "sync.enable", defaultValue: "Cloud sync"),
                    isOn: Binding(
                        get: { profile?.cloudSyncEnabled ?? false },
                        set: { newValue in
                            Task { await setCloudSync(newValue) }
                        }
                    )
                )
                .disabled(!container.authentication.isAuthenticated)

                if let last = profile?.lastSuccessfulSyncAt {
                    LabeledContent(
                        String(localized: "sync.last", defaultValue: "Last successful sync"),
                        value: last.formatted(date: .abbreviated, time: .shortened)
                    )
                }

                PrimaryButton(
                    title: String(localized: "sync.now", defaultValue: "Sync now"),
                    isEnabled: (profile?.cloudSyncEnabled ?? false) && container.authentication.isAuthenticated,
                    isLoading: isSyncing || container.syncCoordinator.isSyncing
                ) {
                    Task { await syncNow() }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if !conflicts.isEmpty {
                Section(String(localized: "sync.conflicts", defaultValue: "Needs attention")) {
                    NavigationLink(value: AppRoute.conflictResolution) {
                        Text(
                            String(
                                localized: "sync.conflicts.count",
                                defaultValue: "\(conflicts.count) item(s) need conflict resolution"
                            )
                        )
                    }
                }
            }

            Section {
                NavigationLink(value: AppRoute.authentication) {
                    Text(String(localized: "sync.account", defaultValue: "Account"))
                }
                NavigationLink(value: AppRoute.localToCloudMigration) {
                    Text(String(localized: "sync.migration", defaultValue: "Upload local collection"))
                }
            }

            if let message {
                Section {
                    Text(message)
                        .font(.evidenceCaption())
                        .foregroundStyle(EvidenceFallbackColors.muted)
                }
            }

            Section {
                Text(
                    String(
                        localized: "sync.limitation",
                        defaultValue: "Conflict resolution uses timestamps. When both sides changed, Evidence may keep a local copy before overwriting."
                    )
                )
                .font(.evidenceCaption())
                .foregroundStyle(EvidenceFallbackColors.muted)
            }
        }
        .navigationTitle(String(localized: "sync.nav", defaultValue: "Account and sync"))
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .conflictResolution:
                ConflictResolutionView()
            case .authentication:
                AuthenticationView()
            case .localToCloudMigration:
                LocalToCloudMigrationView()
            default:
                EmptyView()
            }
        }
    }

    private func setCloudSync(_ enabled: Bool) async {
        let profile = await container.ensureProfile()
        guard container.authentication.isAuthenticated else {
            message = String(localized: "sync.signInFirst", defaultValue: "Sign in before enabling cloud sync.")
            return
        }
        profile.cloudSyncEnabled = enabled
        profile.authenticatedUserID = container.authentication.currentUserID
        profile.touch()
        try? await container.profileRepository.save(profile)
        if enabled {
            await syncNow()
        }
    }

    private func syncNow() async {
        isSyncing = true
        defer { isSyncing = false }
        await container.syncCoordinator.syncNow()
        if let error = container.syncCoordinator.lastErrorMessage {
            message = error
        } else {
            message = String(localized: "sync.done", defaultValue: "Sync finished. Your local collection remains available offline.")
        }
    }
}

struct ConflictResolutionView: View {
    @Environment(AppContainer.self) private var container
    @Query(filter: #Predicate<EvidenceEntry> { $0.syncStatusRaw == "conflict" })
    private var conflicts: [EvidenceEntry]

    @State private var message: String?

    var body: some View {
        List {
            Section(
                footer: Text(
                    String(
                        localized: "conflict.footer",
                        defaultValue: "Choose keep local, keep cloud (mark for re-download on next sync), or keep both as duplicates."
                    )
                )
            ) {
                if conflicts.isEmpty {
                    Text(String(localized: "conflict.empty", defaultValue: "No conflicts right now."))
                        .foregroundStyle(EvidenceFallbackColors.muted)
                } else {
                    ForEach(conflicts, id: \.id) { entry in
                        VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.sm) {
                            Text(entry.title)
                                .font(.evidenceBody().weight(.semibold))
                            Text(entry.meaningPromptAnswer)
                                .font(.evidenceCaption())
                                .foregroundStyle(EvidenceFallbackColors.muted)
                            HStack {
                                Button(String(localized: "conflict.keepLocal", defaultValue: "Keep local")) {
                                    Task { await keepLocal(entry) }
                                }
                                Button(String(localized: "conflict.keepCloud", defaultValue: "Prefer cloud")) {
                                    Task { await preferCloud(entry) }
                                }
                                Button(String(localized: "conflict.duplicate", defaultValue: "Keep both")) {
                                    Task { await duplicate(entry) }
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, EvidenceTheme.Spacing.xs)
                    }
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
        .navigationTitle(String(localized: "conflict.nav", defaultValue: "Resolve conflicts"))
    }

    private func keepLocal(_ entry: EvidenceEntry) async {
        entry.markPendingUpload()
        try? await container.entryRepository.save(entry)
        message = String(localized: "conflict.keptLocal", defaultValue: "Local version will upload on next sync.")
    }

    private func preferCloud(_ entry: EvidenceEntry) async {
        // Mark synced-looking so next pull can refresh; keep visible access meanwhile.
        entry.syncStatus = .synced
        entry.syncErrorMessage = nil
        entry.touch()
        try? await container.entryRepository.save(entry)
        await container.syncCoordinator.syncNow()
        message = String(localized: "conflict.preferCloud", defaultValue: "Cloud preference recorded. Sync will refresh when available.")
    }

    private func duplicate(_ entry: EvidenceEntry) async {
        let copy = EvidenceEntry(
            ownerUserID: entry.ownerUserID,
            title: entry.title + String(localized: "conflict.copySuffix", defaultValue: " (local copy)"),
            bodyText: entry.bodyText,
            entryType: entry.entryType,
            sourceType: entry.sourceType,
            sourceName: entry.sourceName,
            meaningPromptAnswer: entry.meaningPromptAnswer,
            localImageFileName: entry.localImageFileName,
            accessibilityDescription: entry.accessibilityDescription,
            syncStatus: .localOnly
        )
        try? await container.entryRepository.save(copy)
        entry.syncStatus = .synced
        try? await container.entryRepository.save(entry)
        message = String(localized: "conflict.duplicated", defaultValue: "Kept both versions.")
    }
}
