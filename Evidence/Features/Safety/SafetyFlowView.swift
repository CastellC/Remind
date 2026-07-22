import SwiftUI
import UIKit

/// Wires safety support into NavigationStack flows using `SafetySupportView`.
struct SafetyFlowView: View {
    let state: SafetyState
    var onContinueToGrounding: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showGrounding = false
    @State private var reflectionNote = ""
    @State private var showReflection = false

    var body: some View {
        Group {
            if showGrounding {
                RecommendationView(mode: .standaloneGrounding) {
                    dismiss()
                }
            } else if let mode = SafetySupportView.mode(for: state) {
                SafetySupportView(mode: mode, trustedContactAvailable: false) { action in
                    handle(action)
                }
            } else {
                RecommendationView(mode: .standaloneGrounding) {
                    dismiss()
                }
            }
        }
        .navigationTitle(String(localized: "safety.nav", defaultValue: "Support"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReflection) {
            NavigationStack {
                Form {
                    Section {
                        TextField(
                            String(
                                localized: "safety.reflection.placeholder",
                                defaultValue: "Write what you directly observed, or what you are assuming"
                            ),
                            text: $reflectionNote,
                            axis: .vertical
                        )
                        .lineLimit(4...10)
                    } footer: {
                        Text(
                            String(
                                localized: "safety.reflection.footer",
                                defaultValue: "This stays on your device unless you choose otherwise elsewhere."
                            )
                        )
                    }
                }
                .navigationTitle(String(localized: "safety.reflection.nav", defaultValue: "Reflection"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "action.close", defaultValue: "Close")) {
                            showReflection = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func handle(_ action: SafetySupportView.Action) {
        switch action {
        case .tryGrounding, .iAmSafeRightNow:
            showGrounding = true
            onContinueToGrounding?()
        case .callTrustedContact:
            if let url = URL(string: "tel:"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        case .messageTrustedContact:
            if let url = URL(string: "sms:"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        case .writeWhatIObserved, .identifyAssumptions:
            showReflection = true
        case .exit:
            dismiss()
        }
    }
}
