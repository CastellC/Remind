import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Theme tokens

/// Calm, warm, restrained visual tokens for Evidence.
/// Prefer system semantic colors; accent is a soft teal (not purple).
enum EvidenceTheme {
    static let brandName = "Evidence"
    static let tagline = "Remember what is true"

    static let disclaimer = String(
        localized: "disclaimer.support",
        defaultValue: "Evidence supports personal reflection and grounding. It does not diagnose conditions, provide medical treatment, or replace professional care."
    )

    /// Practical minimum interactive target (WCAG / HIG).
    static let minimumTouchTarget: CGFloat = 44

    /// Alias used by feature screens.
    static let minTouchTarget: CGFloat = minimumTouchTarget

    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
        static let xxxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16

        /// Compatibility aliases for feature screens.
        static let small: CGFloat = sm
        static let medium: CGFloat = md
        static let large: CGFloat = 20
    }

    enum Stroke {
        static let hairline: CGFloat = 1
        static let emphasis: CGFloat = 1.5
    }
}

// MARK: - Fallback / warm neutrals

/// Warm neutrals when a slightly warmer canvas than pure system white is desired.
enum EvidenceFallbackColors {
    static let canvasLight = Color(red: 0.96, green: 0.95, blue: 0.93)
    static let canvasDark = Color(red: 0.11, green: 0.12, blue: 0.13)
    static let ink = Color(red: 0.18, green: 0.17, blue: 0.16)
    static let muted = Color(red: 0.42, green: 0.40, blue: 0.38)
    /// Soft teal accent — warm earth, not purple.
    static let accent = Color(red: 0.28, green: 0.42, blue: 0.40)
    static let softFill = Color(red: 0.90, green: 0.89, blue: 0.86)
}

// MARK: - Colors

extension Color {
    /// Soft teal accent — warm and restrained in light and dark mode.
    static var evidenceAccent: Color {
        #if canImport(UIKit)
        Color(UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.45, green: 0.72, blue: 0.70, alpha: 1)
            }
            return UIColor(red: 0.22, green: 0.52, blue: 0.50, alpha: 1)
        })
        #else
        EvidenceFallbackColors.accent
        #endif
    }

    /// Soft fill behind selected / emphasized interactive surfaces.
    static var evidenceAccentSoft: Color {
        evidenceAccent.opacity(0.14)
    }

    /// Warm secondary surface (system secondary background).
    static var evidenceSurface: Color {
        #if canImport(UIKit)
        Color(UIColor.secondarySystemBackground)
        #else
        Color.gray.opacity(0.12)
        #endif
    }

    /// Primary canvas (system background).
    static var evidenceBackground: Color {
        #if canImport(UIKit)
        Color(UIColor.systemBackground)
        #else
        Color.white
        #endif
    }

    /// Optional warm canvas — falls back to system background if asset missing.
    static var evidenceCanvas: Color {
        #if canImport(UIKit)
        Color(UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1)
            }
            return UIColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1)
        })
        #else
        EvidenceFallbackColors.canvasLight
        #endif
    }

    /// Grouped / inset canvas.
    static var evidenceGroupedBackground: Color {
        #if canImport(UIKit)
        Color(UIColor.systemGroupedBackground)
        #else
        Color.gray.opacity(0.08)
        #endif
    }

    /// Subtle separator using system separator.
    static var evidenceSeparator: Color {
        #if canImport(UIKit)
        Color(UIColor.separator)
        #else
        Color.secondary.opacity(0.35)
        #endif
    }

    /// Warm neutral for secondary labels (system secondary label).
    static var evidenceSecondaryLabel: Color {
        #if canImport(UIKit)
        Color(UIColor.secondaryLabel)
        #else
        Color.secondary
        #endif
    }

    /// Tertiary label for hints and captions.
    static var evidenceTertiaryLabel: Color {
        #if canImport(UIKit)
        Color(UIColor.tertiaryLabel)
        #else
        Color.secondary.opacity(0.8)
        #endif
    }

    /// Caution / attention without clinical red urgency for ordinary UI.
    static var evidenceAttention: Color {
        Color.orange
    }

    /// Sync / status success uses system green.
    static var evidenceSuccess: Color {
        Color.green
    }
}

// MARK: - View helpers

extension View {
    /// Applies a calm selection treatment without relying on color alone.
    func evidenceSelectedBackground(_ selected: Bool) -> some View {
        background(
            RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
                .fill(selected ? Color.evidenceAccentSoft : Color.evidenceSurface)
        )
    }

    /// Soft continuous clip matching modest radius tokens.
    func evidenceClip(_ radius: CGFloat = EvidenceTheme.Radius.md) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Ensures a practical minimum interactive height.
    func evidenceMinTouchTarget(minLength: CGFloat = EvidenceTheme.minimumTouchTarget) -> some View {
        frame(minWidth: minLength, minHeight: minLength)
    }

    /// Animates only when Reduce Motion is off.
    func evidenceAnimation<V: Equatable>(
        _ animation: Animation?,
        value: V,
        reduceMotion: Bool
    ) -> some View {
        self.animation(reduceMotion ? nil : animation, value: value)
    }
}

// MARK: - Animation

enum EvidenceMotion {
    /// Soft emphasis for selection changes when motion is allowed.
    static let selection: Animation = .easeInOut(duration: 0.22)

    /// Gentle appear / dismiss.
    static let appear: Animation = .easeOut(duration: 0.28)

    static func selection(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : selection
    }

    static func appear(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : appear
    }
}
