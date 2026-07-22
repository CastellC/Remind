import SwiftUI

/// Calm empty-state placeholder with optional action.
struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "tray"
    var actionTitle: String? = nil
    var actionHint: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: EvidenceTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Color.evidenceSecondaryLabel)
                .accessibilityHidden(true)

            Text(title)
                .font(EvidenceTypography.emptyTitle)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(EvidenceTypography.body)
                .foregroundStyle(Color.evidenceSecondaryLabel)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                PrimaryButton(
                    title: actionTitle,
                    accessibilityHintText: actionHint,
                    action: action
                )
                .padding(.top, EvidenceTheme.Spacing.xs)
                .frame(maxWidth: 320)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, EvidenceTheme.Spacing.lg)
        .padding(.vertical, EvidenceTheme.Spacing.xl)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(message)")
    }
}

#Preview {
    EmptyStateView(
        title: "Nothing here yet",
        message: "Save something meaningful you may need on a difficult day.",
        systemImage: "tray",
        actionTitle: "Add evidence",
        action: {}
    )
}
