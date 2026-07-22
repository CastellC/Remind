import SwiftUI

/// Optional 1…5 intensity picker using product check-in labels.
struct IntensityPicker: View {
    @Binding var intensity: Int?
    var allowsSkip: Bool = true
    var title: String = "How intense does this feel?"
    var onSkip: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let levels = Array(1...5)

    var body: some View {
        VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.sm) {
            Text(title)
                .font(EvidenceTypography.headline)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            Text("Optional")
                .font(EvidenceTypography.caption)
                .foregroundStyle(Color.evidenceTertiaryLabel)

            VStack(spacing: EvidenceTheme.Spacing.xs) {
                ForEach(levels, id: \.self) { level in
                    intensityRow(level)
                }
            }

            if allowsSkip {
                SecondaryButton(
                    title: "Skip",
                    accessibilityHintText: "Continue without choosing intensity"
                ) {
                    intensity = nil
                    onSkip?()
                }
                .padding(.top, EvidenceTheme.Spacing.xs)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func intensityRow(_ level: Int) -> some View {
        let label = CheckIn.intensityLabels[level] ?? "\(level)"
        let isSelected = intensity == level

        return Button {
            intensity = level
        } label: {
            HStack(spacing: EvidenceTheme.Spacing.sm) {
                Text("\(level)")
                    .font(EvidenceTypography.headline)
                    .foregroundStyle(isSelected ? Color.evidenceAccent : Color.evidenceSecondaryLabel)
                    .frame(width: 28, alignment: .center)
                    .accessibilityHidden(true)

                Text(label)
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
        .accessibilityLabel("\(level), \(label)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to select this intensity")
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

private struct IntensityPickerPreviewHost: View {
    @State private var value: Int? = 2

    var body: some View {
        IntensityPicker(intensity: $value)
            .padding()
    }
}

#Preview {
    IntensityPickerPreviewHost()
}
