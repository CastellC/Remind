import SwiftUI

/// Accessible inline error / validation banner with optional dismiss and retry.
struct ErrorBanner: View {
    let message: String
    var title: String = "Something went wrong"
    var isRetryAvailable: Bool = false
    var retryTitle: String = "Try again"
    var dismissTitle: String = "Dismiss"
    var showsDismiss: Bool = true
    var onRetry: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.sm) {
            HStack(alignment: .top, spacing: EvidenceTheme.Spacing.sm) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.red)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.xxxs) {
                    Text(title)
                        .font(EvidenceTypography.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .font(EvidenceTypography.callout)
                        .foregroundStyle(Color.evidenceSecondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: EvidenceTheme.Spacing.xs) {
                if isRetryAvailable, let onRetry {
                    Button(action: onRetry) {
                        Text(retryTitle)
                            .font(EvidenceTypography.footnote.weight(.semibold))
                            .foregroundStyle(Color.evidenceAccent)
                            .padding(.horizontal, EvidenceTheme.Spacing.sm)
                            .padding(.vertical, EvidenceTheme.Spacing.xs)
                            .evidenceMinTouchTarget()
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(EvidencePressableButtonStyle(reduceMotion: reduceMotion))
                    .accessibilityLabel(retryTitle)
                    .accessibilityHint("Double tap to try the action again")
                    .accessibilityAddTraits(.isButton)
                }

                if showsDismiss, let onDismiss {
                    Button(action: onDismiss) {
                        Text(dismissTitle)
                            .font(EvidenceTypography.footnote.weight(.medium))
                            .foregroundStyle(Color.evidenceSecondaryLabel)
                            .padding(.horizontal, EvidenceTheme.Spacing.sm)
                            .padding(.vertical, EvidenceTheme.Spacing.xs)
                            .evidenceMinTouchTarget()
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(EvidencePressableButtonStyle(reduceMotion: reduceMotion))
                    .accessibilityLabel(dismissTitle)
                    .accessibilityHint("Double tap to dismiss this message")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .padding(EvidenceTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
                .strokeBorder(Color.red.opacity(0.35), lineWidth: EvidenceTheme.Stroke.hairline)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(message)")
    }
}

#Preview {
    ErrorBanner(
        message: "Sync could not finish. Check your connection and try again.",
        isRetryAvailable: true,
        onRetry: {},
        onDismiss: {}
    )
    .padding()
}
