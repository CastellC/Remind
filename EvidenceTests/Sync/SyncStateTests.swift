import XCTest
@testable import Evidence

final class SyncStateTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_720_000_000)

    // MARK: - SyncStatus transitions / properties

    func testSyncStatusNeedsNetworkWork() {
        XCTAssertFalse(SyncStatus.localOnly.needsNetworkWork)
        XCTAssertFalse(SyncStatus.synced.needsNetworkWork)

        XCTAssertTrue(SyncStatus.pendingUpload.needsNetworkWork)
        XCTAssertTrue(SyncStatus.syncing.needsNetworkWork)
        XCTAssertTrue(SyncStatus.pendingDeletion.needsNetworkWork)
        XCTAssertTrue(SyncStatus.conflict.needsNetworkWork)
        XCTAssertTrue(SyncStatus.failed.needsNetworkWork)
    }

    func testSyncStatusDisplayNamesAreNonEmpty() {
        for status in SyncStatus.allCases {
            XCTAssertFalse(status.displayName.isEmpty)
        }
    }

    // MARK: - Conflict comparison by updatedAt

    func testSkipOverwriteWhenLocalPendingAndNewer() {
        let decision = SyncConflictResolver.decide(
            localUpdated: base.addingTimeInterval(60),
            remoteUpdated: base,
            localStatus: .pendingUpload
        )
        XCTAssertEqual(decision, .skipOverwrite)
    }

    func testSkipOverwriteForPendingDeletionWhenLocalNewer() {
        let decision = SyncConflictResolver.decide(
            localUpdated: base.addingTimeInterval(10),
            remoteUpdated: base,
            localStatus: .pendingDeletion
        )
        XCTAssertEqual(decision, .skipOverwrite)
    }

    func testNearEqualAppliesRemoteWithoutCopy() {
        let decision = SyncConflictResolver.decide(
            localUpdated: base,
            remoteUpdated: base.addingTimeInterval(0.5),
            localStatus: .synced
        )
        XCTAssertEqual(decision, .applyRemoteNearEqual)
        XCTAssertTrue(SyncConflictResolver.areNearlyEqual(base, base.addingTimeInterval(0.5)))
    }

    func testRemoteNewerWithUnsyncedLocalPreservesCopy() {
        for status in [SyncStatus.pendingUpload, .failed, .conflict] {
            let decision = SyncConflictResolver.decide(
                localUpdated: base,
                remoteUpdated: base.addingTimeInterval(120),
                localStatus: status
            )
            XCTAssertEqual(
                decision,
                .preferRemoteWithLocalCopy,
                "Expected local copy for status \(status)"
            )
        }
    }

    func testRemoteNewerWithCleanLocalAppliesRemote() {
        let decision = SyncConflictResolver.decide(
            localUpdated: base,
            remoteUpdated: base.addingTimeInterval(120),
            localStatus: .synced
        )
        XCTAssertEqual(decision, .preferRemote)
    }

    func testLocalNewerMarksPendingUpload() {
        let decision = SyncConflictResolver.decide(
            localUpdated: base.addingTimeInterval(300),
            remoteUpdated: base,
            localStatus: .synced
        )
        XCTAssertEqual(decision, .markLocalPendingUpload)
    }

    func testIsNewerHelper() {
        XCTAssertTrue(SyncConflictResolver.isNewer(base.addingTimeInterval(1), than: base))
        XCTAssertFalse(SyncConflictResolver.isNewer(base, than: base.addingTimeInterval(1)))
    }

    func testUnsyncedLocalStatusesSet() {
        XCTAssertTrue(SyncConflictResolver.unsyncedLocalStatuses.contains(.pendingUpload))
        XCTAssertTrue(SyncConflictResolver.unsyncedLocalStatuses.contains(.conflict))
        XCTAssertFalse(SyncConflictResolver.unsyncedLocalStatuses.contains(.synced))
    }
}
