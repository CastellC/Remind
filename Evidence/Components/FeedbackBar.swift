import SwiftUI

/// Optional post-recommendation feedback using primary `FeedbackResponse` values.
struct FeedbackBar: View {
    var responses: [FeedbackResponse] = FeedbackResponse.primaryResponses
    var selected: FeedbackResponse? = nil
    var accessibilityHintText: String? = nil
    let onSelect: (FeedbackResponse) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.xs) {
            Text("How was this?")
                .font(EvidenceTypography.subheadline)
                .foregroundStyle(Color.evidenceSecondaryLabel)
                .accessibilityAddTraits(.isHeader)

            adaptiveLayout
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var adaptiveLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: EvidenceTheme.Spacing.xs) {
                ForEach(responses) { response in
                    feedbackButton(for: response)
                }
            }
        } else {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: EvidenceTheme.Spacing.xs
            ) {
                ForEach(responses) { response in
                    feedbackButton(for: response)
                }
            }
        }
    }

    private func feedbackButton(for response: FeedbackResponse) -> some View {
        let isSelected = selected == response
        return Button {
            onSelect(response)
        } label: {
            HStack(spacing: EvidenceTheme.Spacing.xxs) {
                if isSelected && differentiateWithoutColor {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
                Text(response.displayName)
                    .font(EvidenceTypography.footnote.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, EvidenceTheme.Spacing.sm)
            .padding(.vertical, EvidenceTheme.Spacing.sm)
            .evidenceMinTouchTarget()
            .background(
                RoundedRectangle(cornerRadius: EvidenceTheme.Radius.sm, style: .continuous)
                    .fill(isSelected ? Color.evidenceAccentSoft : Color.evidenceSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EvidenceTheme.Radius.sm, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.evidenceAccent : Color.evidenceSeparator,
                        lineWidth: isSelected ? EvidenceTheme.Stroke.emphasis : EvidenceTheme.Stroke.hairline
                    )
            )
            .foregroundStyle(isSelected ? Color.evidenceAccent : Color.primary)
        }
        .buttonStyle(EvidencePressableButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(response.displayName)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(accessibilityHintText ?? "Double tap to record this feedback")
        .accessibilityAddTraits(traits(isSelected: isSelected))
        .evidenceAnimation(EvidenceMotion.selection, value: isSelected, reduceMotion: reduceMotion)
    }

    private func traits(isSelected: Bool) -> AccessibilityTraits {
        var result: AccessibilityTraits = .isButton
        if isSelected {
            result.insert(.isSelected)
        }
        return result
    }
}

#Preview {
    FeedbackBar(selected: .helped) { _ in }
        .padding()
}
