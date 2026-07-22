import SwiftUI

// MARK: - Semantic typography

/// Semantic text styles built on `Font.system` Dynamic Type text styles.
/// Prefer these over raw sizes so content scales with accessibility settings.
enum EvidenceTypography {
    /// Large brand / screen title.
    static let largeTitle = Font.system(.largeTitle, design: .default).weight(.semibold)

    /// Primary screen title.
    static let title = Font.system(.title2, design: .default).weight(.semibold)

    /// Secondary section title.
    static let title2 = Font.system(.title3, design: .default).weight(.semibold)

    /// Card / row title.
    static let headline = Font.system(.headline, design: .default)

    /// Emphasized supporting line.
    static let subheadline = Font.system(.subheadline, design: .default).weight(.medium)

    /// Body copy.
    static let body = Font.system(.body, design: .default)

    /// Supporting / secondary body.
    static let callout = Font.system(.callout, design: .default)

    /// Compact labels (chips, metadata).
    static let footnote = Font.system(.footnote, design: .default)

    /// Captions and fine print (disclaimers).
    static let caption = Font.system(.caption, design: .default)

    /// Smallest captions.
    static let caption2 = Font.system(.caption2, design: .default)

    /// Button label.
    static let button = Font.system(.body, design: .default).weight(.semibold)

    /// Secondary button label.
    static let buttonSecondary = Font.system(.body, design: .default).weight(.medium)

    /// Choice card title (emotion / support need).
    static let choiceTitle = Font.system(.body, design: .default).weight(.medium)

    /// Section header.
    static let sectionHeader = Font.system(.title3, design: .default).weight(.semibold)

    /// Empty-state title.
    static let emptyTitle = Font.system(.title3, design: .default).weight(.semibold)

    /// Safety support title — calm, clear hierarchy without alarm styling.
    static let safetyTitle = Font.system(.title2, design: .default).weight(.semibold)
}

// MARK: - View modifiers

extension View {
    func evidenceLargeTitleStyle() -> some View {
        font(EvidenceTypography.largeTitle)
            .foregroundStyle(.primary)
    }

    func evidenceTitleStyle() -> some View {
        font(EvidenceTypography.title)
            .foregroundStyle(.primary)
    }

    func evidenceHeadlineStyle() -> some View {
        font(EvidenceTypography.headline)
            .foregroundStyle(.primary)
    }

    func evidenceBodyStyle() -> some View {
        font(EvidenceTypography.body)
            .foregroundStyle(.primary)
    }

    func evidenceSecondaryBodyStyle() -> some View {
        font(EvidenceTypography.callout)
            .foregroundStyle(Color.evidenceSecondaryLabel)
    }

    func evidenceCaptionStyle() -> some View {
        font(EvidenceTypography.caption)
            .foregroundStyle(Color.evidenceTertiaryLabel)
    }

    func evidenceSectionHeaderStyle() -> some View {
        font(EvidenceTypography.sectionHeader)
            .foregroundStyle(.primary)
    }
}

// MARK: - Font helpers (Dynamic Type–friendly)

extension Font {
    /// Body text using the body text style (scales with Dynamic Type).
    static func evidenceBody(_ size: CGFloat? = nil) -> Font {
        if let size {
            return .system(size: size, weight: .regular, design: .default)
        }
        return EvidenceTypography.body
    }

    /// Caption / supporting text (scales with Dynamic Type when size omitted).
    static func evidenceCaption(_ size: CGFloat? = nil) -> Font {
        if let size {
            return .system(size: size, weight: .regular, design: .default)
        }
        return EvidenceTypography.caption
    }

    /// Headline convenience for feature screens.
    static func evidenceHeadline() -> Font {
        EvidenceTypography.headline
    }

    /// Title convenience for feature screens.
    static func evidenceTitle(_ size: CGFloat? = nil) -> Font {
        if let size {
            return .system(size: size, weight: .semibold, design: .rounded)
        }
        return EvidenceTypography.title
    }

    /// Soft display / brand title used on lock and about screens.
    static func evidenceDisplay(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}
