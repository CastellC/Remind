import SwiftUI

/// Calm safety-support UI for immediate concern and elevated / persecutory paths.
/// Never auto-contacts anyone. No cheerful affirmations.
struct SafetySupportView: View {
    enum Mode: Equatable, Sendable {
        case immediateConcern
        case elevatedOrPersecutory
    }

    enum Action: Equatable, Sendable {
        case callTrustedContact
        case messageTrustedContact
        case tryGrounding
        case iAmSafeRightNow
        case writeWhatIObserved
        case identifyAssumptions
        case exit
    }

    var mode: Mode
    var content: SafetyContentConfiguration = .loadBundledOrEmbedded()
    var trustedContactAvailable: Bool = false
    var onAction: (Action) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var title: String {
        switch mode {
        case .immediateConcern:
            return content.immediateSupportTitle
        case .elevatedOrPersecutory:
            return content.elevatedSupportTitle
        }
    }

    private var bodyText: String {
        switch mode {
        case .immediateConcern:
            return content.immediateSupportBody
        case .elevatedOrPersecutory:
            return content.elevatedSupportBody
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.lg) {
                header
                actions
                disclaimer
            }
            .padding(EvidenceTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.evidenceGroupedBackground.ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.sm) {
            Image(systemName: mode == .immediateConcern ? "lifepreserver" : "pause.circle")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Color.evidenceAccent)
                .accessibilityHidden(true)

            Text(title)
                .font(EvidenceTypography.safetyTitle)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(bodyText)
                .font(EvidenceTypography.body)
                .foregroundStyle(Color.evidenceSecondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EvidenceTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
                .fill(Color.evidenceSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
                .strokeBorder(Color.evidenceSeparator.opacity(0.4), lineWidth: EvidenceTheme.Stroke.hairline)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: EvidenceTheme.Spacing.sm) {
            switch mode {
            case .immediateConcern:
                if trustedContactAvailable {
                    PrimaryButton(
                        title: "Call someone I trust",
                        systemImage: "phone",
                        accessibilityHintText: "Opens a call to your trusted contact. Nothing is contacted automatically."
                    ) {
                        onAction(.callTrustedContact)
                    }

                    SecondaryButton(
                        title: "Message someone I trust",
                        systemImage: "message",
                        accessibilityHintText: "Opens a message to your trusted contact. Nothing is contacted automatically."
                    ) {
                        onAction(.messageTrustedContact)
                    }
                } else {
                    SecondaryButton(
                        title: "Contact someone I trust",
                        systemImage: "person.crop.circle",
                        accessibilityHintText: "Use your own contacts. Evidence does not contact anyone automatically."
                    ) {
                        onAction(.messageTrustedContact)
                    }
                }

                SecondaryButton(
                    title: "Try a grounding exercise",
                    systemImage: "leaf",
                    accessibilityHintText: "Opens a calm grounding exercise"
                ) {
                    onAction(.tryGrounding)
                }

                SecondaryButton(
                    title: "I am safe right now",
                    systemImage: "checkmark.circle",
                    accessibilityHintText: "Continues to neutral grounding"
                ) {
                    onAction(.iAmSafeRightNow)
                }

            case .elevatedOrPersecutory:
                SecondaryButton(
                    title: "Write what I directly observed",
                    systemImage: "pencil.and.list.clipboard",
                    accessibilityHintText: "Helps separate observation from fear"
                ) {
                    onAction(.writeWhatIObserved)
                }

                SecondaryButton(
                    title: "Identify what I am assuming",
                    systemImage: "text.magnifyingglass",
                    accessibilityHintText: "Helps name assumptions without judging them"
                ) {
                    onAction(.identifyAssumptions)
                }

                if trustedContactAvailable {
                    SecondaryButton(
                        title: "Call someone I trust",
                        systemImage: "phone",
                        accessibilityHintText: "Opens a call to your trusted contact. Nothing is contacted automatically."
                    ) {
                        onAction(.callTrustedContact)
                    }

                    SecondaryButton(
                        title: "Message someone I trust",
                        systemImage: "message",
                        accessibilityHintText: "Opens a message to your trusted contact. Nothing is contacted automatically."
                    ) {
                        onAction(.messageTrustedContact)
                    }
                } else {
                    SecondaryButton(
                        title: "Contact someone I trust",
                        systemImage: "person.crop.circle",
                        accessibilityHintText: "Use your own contacts. Evidence does not contact anyone automatically."
                    ) {
                        onAction(.messageTrustedContact)
                    }
                }

                SecondaryButton(
                    title: "Try a grounding exercise",
                    systemImage: "leaf",
                    accessibilityHintText: "Opens a calm grounding exercise"
                ) {
                    onAction(.tryGrounding)
                }
            }

            SecondaryButton(
                title: "Exit",
                systemImage: "xmark",
                accessibilityHintText: "Leave this screen"
            ) {
                onAction(.exit)
            }
        }
        .evidenceAnimation(EvidenceMotion.appear, value: mode, reduceMotion: reduceMotion)
    }

    private var disclaimer: some View {
        Text(content.disclaimer)
            .font(EvidenceTypography.caption)
            .foregroundStyle(Color.evidenceTertiaryLabel)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, EvidenceTheme.Spacing.xs)
            .accessibilityLabel("Disclaimer. \(content.disclaimer)")
    }
}

extension SafetySupportView {
    /// Maps a `SafetyState` to the appropriate support mode when elevated or immediate.
    static func mode(for state: SafetyState) -> Mode? {
        switch state {
        case .standard:
            return nil
        case .elevatedConcern:
            return .elevatedOrPersecutory
        case .immediateConcern:
            return .immediateConcern
        }
    }
}

#Preview("Immediate") {
    SafetySupportView(mode: .immediateConcern, trustedContactAvailable: true) { _ in }
}

#Preview("Elevated") {
    SafetySupportView(mode: .elevatedOrPersecutory, trustedContactAvailable: false) { _ in }
}
