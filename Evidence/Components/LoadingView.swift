import SwiftUI

/// Calm loading indicator with optional message. Respects Reduce Motion.
struct LoadingView: View {
    var message: String = "Loading"
    var style: Style = .inline

    enum Style {
        case inline
        case fullScreen
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch style {
            case .inline:
                content
                    .padding(EvidenceTheme.Spacing.md)
            case .fullScreen:
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.evidenceBackground.opacity(0.92))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var content: some View {
        VStack(spacing: EvidenceTheme.Spacing.sm) {
            if reduceMotion {
                Image(systemName: "hourglass")
                    .font(.title2)
                    .foregroundStyle(Color.evidenceAccent)
                    .accessibilityHidden(true)
            } else {
                ProgressView()
                    .controlSize(.regular)
                    .tint(Color.evidenceAccent)
                    .accessibilityHidden(true)
            }

            Text(message)
                .font(EvidenceTypography.callout)
                .foregroundStyle(Color.evidenceSecondaryLabel)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    LoadingView(message: "Preparing your check-in", style: .fullScreen)
}
