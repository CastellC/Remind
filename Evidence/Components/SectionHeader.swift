import SwiftUI

/// Semantic section header with optional supporting text and trailing action.
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var actionHint: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: EvidenceTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.xxxs) {
                Text(title)
                    .font(EvidenceTypography.sectionHeader)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(EvidenceTypography.footnote)
                        .foregroundStyle(Color.evidenceSecondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(EvidenceTypography.subheadline)
                        .foregroundStyle(Color.evidenceAccent)
                        .padding(.vertical, EvidenceTheme.Spacing.xs)
                        .padding(.horizontal, EvidenceTheme.Spacing.xs)
                        .evidenceMinTouchTarget()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionTitle)
                .accessibilityHint(actionHint ?? "")
                .accessibilityAddTraits(.isButton)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    SectionHeader(
        title: "Your collection",
        subtitle: "Things you may need later",
        actionTitle: "See all",
        action: {}
    )
    .padding()
}
