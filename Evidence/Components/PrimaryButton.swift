import SwiftUI

/// Primary filled action control with accessible touch target and Dynamic Type.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var accessibilityHintText: String? = nil
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: {
            guard isEnabled, !isLoading else { return }
            action()
        }) {
            HStack(spacing: EvidenceTheme.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                        .accessibilityHidden(true)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(EvidenceTypography.button)
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
                    .fill(isEnabled && !isLoading ? Color.evidenceAccent : Color.evidenceAccent.opacity(0.45))
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(EvidencePressableButtonStyle(reduceMotion: reduceMotion))
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHintText ?? "")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isLoading ? "Loading" : "")
    }
}

/// Shared press feedback that respects Reduce Motion.
struct EvidencePressableButtonStyle: ButtonStyle {
    var reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.98 : 1))
            .animation(EvidenceMotion.selection(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Continue", systemImage: "arrow.right") {}
        PrimaryButton(title: "Saving…", isLoading: true) {}
        PrimaryButton(title: "Unavailable", isEnabled: false) {}
    }
    .padding()
}
