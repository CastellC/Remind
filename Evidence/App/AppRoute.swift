import SwiftUI

/// Routes used with NavigationStack across Evidence.
enum AppRoute: Hashable {
    case entryDetail(UUID)
    case entryEditor(EntryEditorPresentation)
    case checkIn
    case recommendation
    case grounding
    case safetySupport(SafetyState)
    case categoryManager
    case archivedEntries
    case notificationSettings
    case meaningfulDateSettings
    case syncSettings
    case conflictResolution
    case appLockSettings
    case privacy
    case safetyInformation
    case accessibilityStatement
    case export
    case deleteData
    case deleteAccount
    case authentication
    case magicLink
    case localToCloudMigration
    case about
    case howEvidenceWorks
    case replayOnboarding
}

enum EntryEditorPresentation: Hashable {
    case create
    case edit(UUID)
    case firstEntry
}

enum MainTab: Hashable {
    case today
    case collection
    case settings
}
