import XCTest
import SwiftData
@testable import Evidence

final class EvidenceTests: XCTestCase {
    func testBundleLoads() {
        XCTAssertTrue(true, "EvidenceTests bundle loads")
    }

    func testFixedProvidersAreDeterministic() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let dates = FixedDateProvider(now: date)
        XCTAssertEqual(dates.now, date)

        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let uuids = FixedUUIDProvider(uuids: [id])
        XCTAssertEqual(uuids.makeUUID(), id)
    }

    func testInMemoryModelContainerCreates() throws {
        let container = try ModelContainer.evidence(inMemory: true)
        XCTAssertNotNil(container)
    }
}
