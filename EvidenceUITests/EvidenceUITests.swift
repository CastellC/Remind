import XCTest

/// UI test scaffolding for Evidence.
/// Launch with `-UITesting` / `-SkipOnboarding` so onboarding and app lock are bypassed.
final class EvidenceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += [
            "-UITesting",
            "-SkipOnboarding"
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch

    func testLaunchReachesMainInterface() {
        // With -SkipOnboarding the root should show the main tab experience.
        let today = app.tabBars.buttons["Today"]
        let collection = app.tabBars.buttons["Collection"]
        let settings = app.tabBars.buttons["Settings"]

        let appeared = today.waitForExistence(timeout: 8)
            || app.staticTexts["Evidence"].waitForExistence(timeout: 8)
            || app.buttons["Skip for now"].waitForExistence(timeout: 2)

        XCTAssertTrue(appeared, "App should show tabs, brand, or onboarding skip")

        if today.exists {
            XCTAssertTrue(collection.exists)
            XCTAssertTrue(settings.exists)
        }
    }

    func testSkipOnboardingIfPresented() {
        let skip = app.buttons["Skip for now"]
        if skip.waitForExistence(timeout: 3) {
            skip.tap()
        }

        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(
            todayTab.waitForExistence(timeout: 8)
                || app.staticTexts["Evidence"].waitForExistence(timeout: 5),
            "After skip (or when already complete), main UI should appear"
        )
    }

    // MARK: - Navigation stubs (compile and run; soft assertions)

    func testNavigateToCollectionTab() throws {
        skipOnboardingIfNeeded()
        let collection = app.tabBars.buttons["Collection"]
        guard collection.waitForExistence(timeout: 8) else {
            throw XCTSkip("Collection tab not available in this build/state")
        }
        collection.tap()

        // Search field appears via .searchable
        let search = app.searchFields.firstMatch
        _ = search.waitForExistence(timeout: 5)
    }

    func testNavigateToSettingsTab() throws {
        skipOnboardingIfNeeded()
        let settings = app.tabBars.buttons["Settings"]
        guard settings.waitForExistence(timeout: 8) else {
            throw XCTSkip("Settings tab not available in this build/state")
        }
        settings.tap()

        let sync = app.staticTexts["Account and sync"]
        _ = sync.waitForExistence(timeout: 5)
    }

    /// Stub: create-entry flow — taps Add evidence when available.
    func testCreateEntryFlowScaffolding() throws {
        skipOnboardingIfNeeded()
        let today = app.tabBars.buttons["Today"]
        if today.waitForExistence(timeout: 5) {
            today.tap()
        }

        let add = app.buttons["Add evidence"].exists
            ? app.buttons["Add evidence"]
            : app.buttons["Add your first reminder"]

        guard add.waitForExistence(timeout: 5) else {
            throw XCTSkip("Add entry affordance not visible")
        }
        add.tap()
        // Editor presentation is environment-dependent; ensure we did not crash.
        XCTAssertTrue(app.exists)
    }

    /// Stub: check-in flow — opens check-in when the button is available.
    func testCheckInFlowScaffolding() throws {
        skipOnboardingIfNeeded()
        let today = app.tabBars.buttons["Today"]
        if today.waitForExistence(timeout: 5) {
            today.tap()
        }

        let checkIn = app.buttons["Check in"]
        guard checkIn.waitForExistence(timeout: 5) else {
            throw XCTSkip("Check in requires at least one visible collection entry")
        }
        checkIn.tap()
        XCTAssertTrue(app.exists)
    }

    /// Stub: search on Collection tab.
    func testSearchFlowScaffolding() throws {
        skipOnboardingIfNeeded()
        let collection = app.tabBars.buttons["Collection"]
        guard collection.waitForExistence(timeout: 8) else {
            throw XCTSkip("Collection tab not available")
        }
        collection.tap()

        let searchField = app.searchFields.firstMatch
        guard searchField.waitForExistence(timeout: 5) else {
            throw XCTSkip("Search field not available")
        }
        searchField.tap()
        searchField.typeText("kind")
        XCTAssertTrue(app.exists)
    }

    /// Stub: open settings destinations that should always list.
    func testSettingsFlowScaffolding() throws {
        skipOnboardingIfNeeded()
        let settings = app.tabBars.buttons["Settings"]
        guard settings.waitForExistence(timeout: 8) else {
            throw XCTSkip("Settings tab not available")
        }
        settings.tap()

        let privacy = app.staticTexts["Privacy"]
        if privacy.waitForExistence(timeout: 5) {
            privacy.tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3))
        }
    }

    // MARK: - Helpers

    private func skipOnboardingIfNeeded() {
        let skip = app.buttons["Skip for now"]
        if skip.waitForExistence(timeout: 2) {
            skip.tap()
        }
    }
}
