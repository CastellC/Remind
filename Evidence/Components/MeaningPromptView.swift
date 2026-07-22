import SwiftUI

/// “Why might future you need this?” prompt with selectable meaning suggestions.
struct MeaningPromptView: View {
    @Binding var answer: String
    var selectedSuggestion: MeaningSuggestion? = nil
    var promptQuestion: String = MeaningSuggestion.promptQuestion
    var suggestions: [MeaningSuggestion] = MeaningSuggestion.allCases
    var customPlaceholder: String = "Write your own meaning"
    var onSelectSuggestion: ((MeaningSuggestion) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isCustomFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.sm) {
            Text(promptQuestion)
                .font(EvidenceTypography.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("This answer helps Evidence retrieve this later for the right moment.")
                .font(EvidenceTypography.footnote)
                .foregroundStyle(Color.evidenceSecondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: EvidenceTheme.Spacing.xs) {
                ForEach(suggestions) { suggestion in
                    suggestionRow(suggestion)
                }
            }

            if showsCustomField {
                TextField(customPlaceholder, text: $answer, axis: .vertical)
                    .font(EvidenceTypography.body)
                    .lineLimit(3...8)
                    .padding(EvidenceTheme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
                            .fill(Color.evidenceSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
                            .strokeBorder(Color.evidenceSeparator, lineWidth: EvidenceTheme.Stroke.hairline)
                    )
                    .focused($isCustomFocused)
                    .accessibilityLabel("Custom meaning")
                    .accessibilityHint("Describe why future you may need this")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var showsCustomField: Bool {
        selectedSuggestion?.expectsCustomText == true
            || selectedSuggestion == nil && !answer.isEmpty && !suggestions.map(\.displayName).contains(answer)
            || selectedSuggestion == .somethingElse
    }

    private func suggestionRow(_ suggestion: MeaningSuggestion) -> some View {
        let isSelected = isSuggestionSelected(suggestion)
        return Button {
            select(suggestion)
        } label: {
            HStack(spacing: EvidenceTheme.Spacing.sm) {
                Text(suggestion.displayName)
                    .font(EvidenceTypography.choiceTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
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
        .accessibilityLabel(suggestion.displayName)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(
            suggestion.expectsCustomText
                ? "Double tap, then write your own meaning"
                : "Double tap to use this meaning"
        )
        .accessibilityAddTraits(traits(isSelected: isSelected))
        .evidenceAnimation(EvidenceMotion.selection, value: isSelected, reduceMotion: reduceMotion)
    }

    private func isSuggestionSelected(_ suggestion: MeaningSuggestion) -> Bool {
        if let selectedSuggestion {
            return selectedSuggestion == suggestion
        }
        return answer == suggestion.displayName
    }

    private func select(_ suggestion: MeaningSuggestion) {
        onSelectSuggestion?(suggestion)
        if suggestion.expectsCustomText {
            if suggestions.map(\.displayName).contains(answer) {
                answer = ""
            }
            isCustomFocused = true
        } else {
            answer = suggestion.displayName
            isCustomFocused = false
        }
    }

    private func traits(isSelected: Bool) -> AccessibilityTraits {
        var result: AccessibilityTraits = .isButton
        if isSelected {
            result.insert(.isSelected)
        }
        return result
    }
}

private struct MeaningPromptViewPreviewHost: View {
    @State private var answer = ""
    @State private var selected: MeaningSuggestion?

    var body: some View {
        ScrollView {
            MeaningPromptView(
                answer: $answer,
                selectedSuggestion: selected,
                onSelectSuggestion: { selected = $0 }
            )
            .padding()
        }
    }
}

#Preview {
    MeaningPromptViewPreviewHost()
}
