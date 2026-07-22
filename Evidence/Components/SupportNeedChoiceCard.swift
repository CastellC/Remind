import SwiftUI

/// Accessible choice control for selecting a `SupportNeed`.
struct SupportNeedChoiceCard: View {
    let supportNeed: SupportNeed
    var isSelected: Bool = false
    var accessibilityHintText: String? = nil
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        Button(action: action) {
            HStack(spacing: EvidenceTheme.Spacing.sm) {
                Image(systemName: supportNeed.symbolName)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.evidenceAccent : Color.evidenceSecondaryLabel)
                    .frame(width: 28, alignment: .center)
                    .accessibilityHidden(true)

                Text(supportNeed.displayName)
                    .font(EvidenceTypography.choiceTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: differentiateWithoutColor ? "checkmark.circle.fill" : "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.evidenceAccent)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, EvidenceTheme.Spacing.md)
            .padding(.vertical, EvidenceTheme.Spacing.sm)
            .evidenceMinTouchTarget()
            .background(
                RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
                    .fill(isSelected ? Color.evidenceAccentSoft : Color.evidenceSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.evidenceAccent : Color.evidenceSeparator.opacity(0.6),
                        lineWidth: isSelected ? EvidenceTheme.Stroke.emphasis : EvidenceTheme.Stroke.hairline
                    )
            )
        }
        .buttonStyle(EvidencePressableButtonStyle(reduceMotion: reduceMotion))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(supportNeed.displayName)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(accessibilityHintText ?? "Double tap to select this kind of support")
        .accessibilityAddTraits(traits)
        .evidenceAnimation(EvidenceMotion.selection, value: isSelected, reduceMotion: reduceMotion)
    }

    private var traits: AccessibilityTraits {
        var result: AccessibilityTraits = .isButton
        if isSelected {
            result.insert(.isSelected)
        }
        return result
    }
}

#Preview {
    VStack(spacing: 8) {
        SupportNeedChoiceCard(supportNeed: .reassurance, isSelected: true) {}
        SupportNeedChoiceCard(supportNeed: .grounding) {}
    }
    .padding()
}
