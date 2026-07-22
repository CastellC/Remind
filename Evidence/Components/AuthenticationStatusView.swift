import SwiftUI

/// Shows whether the user is signed in for cloud sync or using the app locally.
struct AuthenticationStatusView: View {
    enum State: Equatable, Sendable {
        case localOnly
        case signedIn(emailOrLabel: String?)
        case signingIn
        case unavailable
        case error(message: String)
    }

    let state: State
    var showsAction: Bool = false
    var actionTitle: String? = nil
    var actionHint: String? = nil
    var action: (() -> Void)? = nil

    init(
        state: State,
        showsAction: Bool = false,
        actionTitle: String? = nil,
        actionHint: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.state = state
        self.showsAction = showsAction
        self.actionTitle = actionTitle
        self.actionHint = actionHint
        self.action = action
    }

    /// Convenience for settings / auth screens that pass booleans.
    init(
        isAuthenticated: Bool,
        cloudSyncEnabled: Bool,
        emailOrLabel: String? = nil,
        showsAction: Bool = false,
        actionTitle: String? = nil,
        actionHint: String? = nil,
        action: (() -> Void)? = nil
    ) {
        if isAuthenticated {
            if let emailOrLabel, !emailOrLabel.isEmpty {
                self.state = .signedIn(emailOrLabel: emailOrLabel)
            } else if cloudSyncEnabled {
                self.state = .signedIn(
                    emailOrLabel: String(localized: "auth.syncOn", defaultValue: "Cloud sync is on")
                )
            } else {
                self.state = .signedIn(
                    emailOrLabel: String(localized: "auth.syncPaused", defaultValue: "Cloud sync is paused")
                )
            }
        } else {
            self.state = .localOnly
        }
        self.showsAction = showsAction
        self.actionTitle = actionTitle
        self.actionHint = actionHint
        self.action = action
    }

    var body: some View {
        HStack(alignment: .center, spacing: EvidenceTheme.Spacing.sm) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(symbolColor)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.xxxs) {
                Text(title)
                    .font(EvidenceTypography.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(EvidenceTypography.footnote)
                    .foregroundStyle(Color.evidenceSecondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if case .signingIn = state {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Signing in")
            } else if showsAction, let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(EvidenceTypography.footnote.weight(.semibold))
                        .foregroundStyle(Color.evidenceAccent)
                        .padding(.horizontal, EvidenceTheme.Spacing.xs)
                        .padding(.vertical, EvidenceTheme.Spacing.xs)
                        .evidenceMinTouchTarget()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionTitle)
                .accessibilityHint(actionHint ?? "")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(EvidenceTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
                .fill(Color.evidenceSurface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }

    private var title: String {
        switch state {
        case .localOnly:
            return "On this device"
        case .signedIn:
            return "Signed in"
        case .signingIn:
            return "Signing in"
        case .unavailable:
            return "Cloud sign-in unavailable"
        case .error:
            return "Sign-in issue"
        }
    }

    private var subtitle: String {
        switch state {
        case .localOnly:
            return "Your evidence stays local unless you enable optional sync."
        case .signedIn(let label):
            if let label, !label.isEmpty {
                return label
            }
            return "Private sync is available for this account."
        case .signingIn:
            return "Please wait."
        case .unavailable:
            return "Cloud credentials are not configured on this build."
        case .error(let message):
            return message
        }
    }

    private var symbolName: String {
        switch state {
        case .localOnly:
            return "iphone"
        case .signedIn:
            return "person.crop.circle.badge.checkmark"
        case .signingIn:
            return "person.crop.circle"
        case .unavailable:
            return "icloud.slash"
        case .error:
            return "exclamationmark.circle"
        }
    }

    private var symbolColor: Color {
        switch state {
        case .localOnly, .signingIn:
            return Color.evidenceSecondaryLabel
        case .signedIn:
            return Color.evidenceAccent
        case .unavailable:
            return Color.evidenceAttention
        case .error:
            return Color.red
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        AuthenticationStatusView(state: .localOnly, showsAction: true, actionTitle: "Sign in", action: {})
        AuthenticationStatusView(state: .signedIn(emailOrLabel: "Signed in with Apple"))
        AuthenticationStatusView(state: .unavailable)
    }
    .padding()
}
