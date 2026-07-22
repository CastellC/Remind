import SwiftUI

/// Selectable chip for tags and lightweight filters.
struct TagChip: View {
    let title: String
    var systemImage: String? = nil
    var isSelected: Bool = false
    var isEnabled: Bool = true
    var accessibilityHintText: String? = nil
    var onTap: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        Button {
            guard isEnabled else { return }
            onTap?()
        } label: {
            HStack(spacing: EvidenceTheme.Spacing.xxs) {
                if isSelected && differentiateWithoutColor {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(EvidenceTypography.footnote.weight(.medium))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, EvidenceTheme.Spacing.sm)
            .padding(.vertical, EvidenceTheme.Spacing.xs)
            .evidenceMinTouchTarget()
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.evidenceAccentSoft : Color.evidenceSurface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.evidenceAccent : Color.evidenceSeparator,
                        lineWidth: isSelected ? EvidenceTheme.Stroke.emphasis : EvidenceTheme.Stroke.hairline
                    )
            )
            .foregroundStyle(isSelected ? Color.evidenceAccent : Color.primary)
        }
        .buttonStyle(EvidencePressableButtonStyle(reduceMotion: reduceMotion))
        .disabled(!isEnabled || onTap == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(accessibilityHintText ?? (onTap == nil ? "" : "Double tap to toggle selection"))
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
    HStack {
        TagChip(title: "Capable", isSelected: true) {}
        TagChip(title: "Caring", systemImage: "heart") {}
    }
    .padding()
}
