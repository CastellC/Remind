import SwiftUI

/// Compact sync status indicator with icon, label, and optional detail.
struct SyncStatusView: View {
    let status: SyncStatus
    var detail: String? = nil
    var showsLabel: Bool = true
    var style: Style = .row

    enum Style {
        case row
        case compact
        case badge
    }

    var body: some View {
        Group {
            switch style {
            case .row:
                rowContent
            case .compact:
                compactContent
            case .badge:
                badgeContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityValue(detail ?? "")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var rowContent: some View {
        HStack(spacing: EvidenceTheme.Spacing.sm) {
            statusIcon
            if showsLabel {
                VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.xxxs) {
                    Text(status.displayName)
                        .font(EvidenceTypography.subheadline)
                        .foregroundStyle(.primary)
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(EvidenceTypography.caption)
                            .foregroundStyle(Color.evidenceSecondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, EvidenceTheme.Spacing.xs)
        .evidenceMinTouchTarget()
    }

    private var compactContent: some View {
        HStack(spacing: EvidenceTheme.Spacing.xxs) {
            statusIcon
            if showsLabel {
                Text(status.displayName)
                    .font(EvidenceTypography.footnote)
                    .foregroundStyle(Color.evidenceSecondaryLabel)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .evidenceMinTouchTarget()
    }

    private var badgeContent: some View {
        HStack(spacing: EvidenceTheme.Spacing.xxs) {
            Image(systemName: symbolName)
                .font(.caption.weight(.semibold))
                .accessibilityHidden(true)
            if showsLabel {
                Text(status.displayName)
                    .font(EvidenceTypography.caption.weight(.medium))
            }
        }
        .padding(.horizontal, EvidenceTheme.Spacing.sm)
        .padding(.vertical, EvidenceTheme.Spacing.xxs)
        .evidenceMinTouchTarget()
        .foregroundStyle(foreground)
        .background(
            Capsule(style: .continuous)
                .fill(foreground.opacity(0.12))
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        if status == .syncing {
            ProgressView()
                .controlSize(.small)
                .accessibilityHidden(true)
        } else {
            Image(systemName: symbolName)
                .font(.body)
                .foregroundStyle(foreground)
                .accessibilityHidden(true)
        }
    }

    private var symbolName: String {
        switch status {
        case .localOnly:
            return "iphone"
        case .pendingUpload:
            return "arrow.up.circle"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .synced:
            return "checkmark.icloud"
        case .pendingDeletion:
            return "trash.circle"
        case .conflict:
            return "exclamationmark.triangle"
        case .failed:
            return "xmark.icloud"
        }
    }

    private var foreground: Color {
        switch status {
        case .localOnly:
            return Color.evidenceSecondaryLabel
        case .pendingUpload, .pendingDeletion:
            return Color.evidenceAttention
        case .syncing:
            return Color.evidenceAccent
        case .synced:
            return Color.evidenceSuccess
        case .conflict, .failed:
            return Color.red
        }
    }

    private var accessibilityLabelText: String {
        var parts = ["Sync status", status.displayName]
        if status.needsNetworkWork {
            parts.append("Needs network")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        SyncStatusView(status: .synced, style: .row)
        SyncStatusView(status: .syncing, style: .compact)
        SyncStatusView(status: .failed, detail: "Try again when you are online", style: .badge)
    }
    .padding()
}
