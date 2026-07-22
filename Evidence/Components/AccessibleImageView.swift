import SwiftUI

/// Displays an entry image using `accessibilityDescription` for VoiceOver.
struct AccessibleImageView: View {
    let image: Image
    var accessibilityDescription: String?
    var contentMode: ContentMode = .fit
    var cornerRadius: CGFloat = EvidenceTheme.Radius.md

    var body: some View {
        image
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .frame(maxWidth: .infinity)
            .evidenceClip(cornerRadius)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(resolvedDescription)
            .accessibilityAddTraits(.isImage)
    }

    private var resolvedDescription: String {
        let trimmed = accessibilityDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return "Image without a description"
        }
        return trimmed
    }
}

extension AccessibleImageView {
    /// Convenience initializer from a `UIImage` when UIKit is available.
    #if canImport(UIKit)
    init(
        uiImage: UIImage,
        accessibilityDescription: String?,
        contentMode: ContentMode = .fit,
        cornerRadius: CGFloat = EvidenceTheme.Radius.md
    ) {
        self.init(
            image: Image(uiImage: uiImage),
            accessibilityDescription: accessibilityDescription,
            contentMode: contentMode,
            cornerRadius: cornerRadius
        )
    }
    #endif

    /// Placeholder when the image has not loaded yet.
    static func placeholder(
        accessibilityDescription: String? = nil,
        systemImage: String = "photo"
    ) -> some View {
        RoundedRectangle(cornerRadius: EvidenceTheme.Radius.md, style: .continuous)
            .fill(Color.evidenceSurface)
            .overlay {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(Color.evidenceTertiaryLabel)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 160)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                (accessibilityDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                    ? accessibilityDescription!
                    : "Image placeholder"
            )
            .accessibilityAddTraits(.isImage)
    }
}

#Preview {
    AccessibleImageView(
        image: Image(systemName: "photo"),
        accessibilityDescription: "A handwritten note on a desk"
    )
    .frame(height: 200)
    .padding()
}
