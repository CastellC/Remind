import SwiftUI

/// Lightweight list row for an evidence entry — restrained, not card-heavy.
struct EvidenceCard: View {
    let title: String
    let meaningSnippet: String
    let entryType: EntryType
    var isFavorite: Bool = false
    var showsFavoriteControl: Bool = true
    var accessibilityHintText: String? = nil
    var onTap: (() -> Void)? = nil
    var onToggleFavorite: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: EvidenceTheme.Spacing.sm) {
            Image(systemName: entryType.symbolName)
                .font(.title3)
                .foregroundStyle(Color.evidenceAccent)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)
                .accessibilityHidden(true)

            Button {
                onTap?()
            } label: {
                VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.xxs) {
                    Text(title)
                        .font(EvidenceTypography.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !meaningSnippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(meaningSnippet)
                            .font(EvidenceTypography.callout)
                            .foregroundStyle(Color.evidenceSecondaryLabel)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text(entryType.displayName)
                        .font(EvidenceTypography.caption)
                        .foregroundStyle(Color.evidenceTertiaryLabel)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onTap == nil)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityHint(accessibilityHintText ?? (onTap == nil ? "" : "Double tap to open"))
            .accessibilityAddTraits(onTap == nil ? [] : .isButton)

            if showsFavoriteControl {
                Button {
                    onToggleFavorite?()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.body)
                        .foregroundStyle(isFavorite ? Color.evidenceAccent : Color.evidenceSecondaryLabel)
                        .evidenceMinTouchTarget()
                        .contentShape(Rectangle())
                }
                .buttonStyle(EvidencePressableButtonStyle(reduceMotion: reduceMotion))
                .disabled(onToggleFavorite == nil)
                .accessibilityLabel(isFavorite ? "Favorite" : "Not a favorite")
                .accessibilityHint(onToggleFavorite == nil ? "" : "Double tap to \(isFavorite ? "remove from" : "add to") favorites")
                .accessibilityAddTraits(.isButton)
                .accessibilityValue(isFavorite ? "Selected" : "Not selected")
            }
        }
        .padding(.vertical, EvidenceTheme.Spacing.sm)
        .padding(.horizontal, EvidenceTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
                .fill(Color.evidenceSurface.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
                .strokeBorder(Color.evidenceSeparator.opacity(0.35), lineWidth: EvidenceTheme.Stroke.hairline)
        )
        .evidenceAnimation(EvidenceMotion.selection, value: isFavorite, reduceMotion: reduceMotion)
    }

    private var accessibilitySummary: String {
        var parts = [title]
        let trimmed = meaningSnippet.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            parts.append(trimmed)
        }
        parts.append(entryType.displayName)
        if isFavorite {
            parts.append("Favorite")
        }
        return parts.joined(separator: ", ")
    }
}

extension EntryType {
    /// SF Symbol used in list rows and filters.
    var symbolName: String {
        switch self {
        case .text:
            return "text.alignleft"
        case .image:
            return "photo"
        case .guidedReminder:
            return "lightbulb"
        case .groundingTechnique:
            return "leaf"
        case .accomplishment:
            return "checkmark.seal"
        case .meaningfulMemory:
            return "heart.text.square"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        EvidenceCard(
            title: "You handled that well",
            meaningSnippet: "Someone believed I could get through a hard week.",
            entryType: .text,
            isFavorite: true,
            onTap: {},
            onToggleFavorite: {}
        )
        EvidenceCard(
            title: "Feet on the floor",
            meaningSnippet: "This helps ground me.",
            entryType: .groundingTechnique,
            showsFavoriteControl: false
        )
    }
    .padding()
}
