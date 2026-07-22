import SwiftUI

/// Accurate privacy summary for onboarding and settings — no overstated claims.
struct PrivacyNoticeView: View {
    var style: Style = .card
    var showsTitle: Bool = true

    enum Style {
        case card
        case plain
    }

    private let points: [(symbol: String, text: String)] = [
        ("iphone", "Entries are saved on this device first."),
        ("icloud", "Cloud synchronization is optional and uses your private account."),
        ("lock.shield", "Synced media is stored in a private bucket."),
        ("hand.raised", "Evidence does not sell your data or use advertising trackers."),
        ("brain", "Private content is not sent to an AI service."),
        ("bell.badge", "Notification previews are generic by default."),
        ("lock", "App lock can be enabled with Face ID, Touch ID, or your device passcode.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.sm) {
            if showsTitle {
                Label("Privacy", systemImage: "hand.raised.fill")
                    .font(EvidenceTypography.headline)
                    .foregroundStyle(.primary)
                    .labelStyle(.titleAndIcon)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityAddTraits(.isHeader)
            }

            Text("Your evidence stays under your control.")
                .font(EvidenceTypography.callout)
                .foregroundStyle(Color.evidenceSecondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.sm) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .top, spacing: EvidenceTheme.Spacing.sm) {
                        Image(systemName: point.symbol)
                            .font(.body)
                            .foregroundStyle(Color.evidenceAccent)
                            .frame(width: 24, alignment: .center)
                            .accessibilityHidden(true)

                        Text(point.text)
                            .font(EvidenceTypography.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, EvidenceTheme.Spacing.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(style == .card ? EvidenceTheme.Spacing.md : 0)
        .background {
            if style == .card {
                RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
                    .fill(Color.evidenceSurface)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ScrollView {
        PrivacyNoticeView()
            .padding()
    }
}
