import SwiftUI

/// Outlined / tonal secondary action with accessible touch target.
struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isEnabled: Bool = true
    var isDestructive: Bool = false
    var accessibilityHintText: String? = nil
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var foreground: Color {
        if !isEnabled { return Color.evidenceTertiaryLabel }
        return isDestructive ? Color.red : Color.evidenceAccent
    }

    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            action()
        }) {
            HStack(spacing: EvidenceTheme.Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.medium))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(EvidenceTypography.buttonSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, EvidenceTheme.Spacing.md)
            .padding(.vertical, EvidenceTheme.Spacing.sm)
            .evidenceMinTouchTarget()
            .background(
                RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
                    .strokeBorder(foreground.opacity(isEnabled ? 0.55 : 0.25), lineWidth: EvidenceTheme.Stroke.emphasis)
                    .background(
                        RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
                            .fill(Color.evidenceSurface)
                    )
            )
            .foregroundStyle(foreground)
        }
        .buttonStyle(EvidencePressableButtonStyle(reduceMotion: reduceMotion))
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHintText ?? "")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack(spacing: 16) {
        SecondaryButton(title: "Skip for now") {}
        SecondaryButton(title: "Delete", systemImage: "trash", isDestructive: true) {}
    }
    .padding()
}
