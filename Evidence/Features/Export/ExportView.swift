import SwiftUI
import SwiftData
import UIKit

struct ExportView: View {
    @Environment(AppContainer.self) private var container
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var message: String?
    @State private var showShare = false

    var body: some View {
        Form {
            Section(
                footer: Text(
                    String(
                        localized: "export.footer",
                        defaultValue: "Exports profile preferences, categories, tags, entries, meaningful dates, feedback metadata, and images into a folder you can share."
                    )
                )
            ) {
                PrimaryButton(
                    title: String(localized: "export.local", defaultValue: "Export local data"),
                    isLoading: isExporting
                ) {
                    Task { await exportLocal() }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if let message {
                Section {
                    Text(message)
                        .font(.evidenceCaption())
                        .foregroundStyle(EvidenceFallbackColors.muted)
                }
            }

            if exportURL != nil {
                Section {
                    Button(String(localized: "export.share", defaultValue: "Share export")) {
                        showShare = true
                    }
                }
            }
        }
        .navigationTitle(String(localized: "export.nav", defaultValue: "Export"))
        .sheet(isPresented: $showShare) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }

    private func exportLocal() async {
        isExporting = true
        defer { isExporting = false }
        do {
            let url = try await container.exportService.exportLocalArchive()
            exportURL = url
            message = String(
                localized: "export.done",
                defaultValue: "Export ready at \(url.lastPathComponent)."
            )
            showShare = true
        } catch {
            message = error.localizedDescription
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DeleteDataView: View {
    @Environment(AppContainer.self) private var container
    @State private var confirmLocal = false
    @State private var confirmCloud = false
    @State private var resetOnboarding = true
    @State private var reportMessage: String?
    @State private var isWorking = false

    var body: some View {
        Form {
            Section(
                footer: Text(
                    String(
                        localized: "deleteData.footer",
                        defaultValue: "Deletion is permanent. Evidence will explain the outcome, including partial failures."
                    )
                )
            ) {
                Toggle(
                    String(localized: "deleteData.resetOnboarding", defaultValue: "Reset onboarding after local delete"),
                    isOn: $resetOnboarding
                )
                Button(String(localized: "deleteData.local", defaultValue: "Delete local data"), role: .destructive) {
                    confirmLocal = true
                }
                Button(String(localized: "deleteData.cloud", defaultValue: "Delete cloud data"), role: .destructive) {
                    confirmCloud = true
                }
                .disabled(!container.authentication.isAuthenticated)
            }

            if let reportMessage {
                Section {
                    Text(reportMessage)
                        .font(.evidenceCaption())
                        .foregroundStyle(EvidenceFallbackColors.muted)
                }
            }

            if isWorking {
                Section {
                    ProgressView(String(localized: "deleteData.working", defaultValue: "Working…"))
                }
            }
        }
        .navigationTitle(String(localized: "deleteData.nav", defaultValue: "Delete data"))
        .confirmationDialog(
            String(localized: "deleteData.local.confirm", defaultValue: "Delete all local Evidence data?"),
            isPresented: $confirmLocal,
            titleVisibility: .visible
        ) {
            Button(String(localized: "action.delete", defaultValue: "Delete"), role: .destructive) {
                Task { await deleteLocal() }
            }
            Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "deleteData.local.message", defaultValue: "This removes entries, images, and schedules from this device."))
        }
        .confirmationDialog(
            String(localized: "deleteData.cloud.confirm", defaultValue: "Delete cloud Evidence data?"),
            isPresented: $confirmCloud,
            titleVisibility: .visible
        ) {
            Button(String(localized: "action.delete", defaultValue: "Delete"), role: .destructive) {
                Task { await deleteCloud() }
            }
            Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "deleteData.cloud.message", defaultValue: "This requests removal of remote rows and media for your account. Local data is kept unless you also delete it."))
        }
    }

    private func deleteLocal() async {
        isWorking = true
        defer { isWorking = false }
        let report = await container.deletionService.deleteLocalData(resetOnboarding: resetOnboarding)
        reportMessage = summarize(report)
    }

    private func deleteCloud() async {
        isWorking = true
        defer { isWorking = false }
        let report = await container.deletionService.deleteCloudData()
        reportMessage = summarize(report)
    }

    private func summarize(_ report: DeletionReport) -> String {
        if report.succeededFully {
            return String(localized: "deleteData.success", defaultValue: "Deletion finished.")
        }
        let failures = report.failures.joined(separator: " ")
        return String(localized: "deleteData.partial", defaultValue: "Some steps could not finish. \(failures)")
    }
}

struct DeleteAccountView: View {
    @Environment(AppContainer.self) private var container
    @State private var confirm = false
    @State private var typedConfirmation = ""
    @State private var message: String?
    @State private var isWorking = false

    private let requiredPhrase = "DELETE"

    var body: some View {
        Form {
            Section(
                footer: Text(
                    String(
                        localized: "deleteAccount.footer",
                        defaultValue: "This deletes your account and associated remote content when the server confirms it, and clears local Evidence data."
                    )
                )
            ) {
                Text(
                    String(
                        localized: "deleteAccount.prompt",
                        defaultValue: "Type DELETE to confirm."
                    )
                )
                TextField(requiredPhrase, text: $typedConfirmation)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button(String(localized: "deleteAccount.action", defaultValue: "Delete account and all data"), role: .destructive) {
                    confirm = true
                }
                .disabled(typedConfirmation != requiredPhrase || !container.authentication.isAuthenticated)
            }

            if let message {
                Section {
                    Text(message)
                        .font(.evidenceCaption())
                        .foregroundStyle(EvidenceFallbackColors.muted)
                }
            }
        }
        .navigationTitle(String(localized: "deleteAccount.nav", defaultValue: "Delete account"))
        .confirmationDialog(
            String(localized: "deleteAccount.confirm", defaultValue: "Permanently delete your account?"),
            isPresented: $confirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "action.delete", defaultValue: "Delete"), role: .destructive) {
                Task { await deleteAccount() }
            }
            Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
        }
        .overlay {
            if isWorking {
                ProgressView()
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func deleteAccount() async {
        isWorking = true
        defer { isWorking = false }
        let report = await container.deletionService.deleteAccountAndAllData(resetOnboarding: true)
        if report.deletedAccount {
            message = String(localized: "deleteAccount.done", defaultValue: "Account deletion confirmed.")
        } else if report.succeededFully {
            message = String(localized: "deleteAccount.doneLocal", defaultValue: "Local data removed. Remote account deletion needs server confirmation.")
        } else {
            message = String(
                localized: "deleteAccount.partial",
                defaultValue: "Deletion did not fully finish. \(report.failures.joined(separator: " "))"
            )
        }
    }
}
