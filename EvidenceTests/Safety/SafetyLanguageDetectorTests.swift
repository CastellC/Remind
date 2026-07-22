import XCTest
@testable import Evidence

final class SafetyLanguageDetectorTests: XCTestCase {
    private var detector: LocalSafetyLanguageDetector!

    override func setUp() {
        super.setUp()
        detector = LocalSafetyLanguageDetector(content: .embedded)
    }

    // MARK: - Immediate concern

    func testImmediateConcernPhrases() {
        let phrases = [
            "I want to die",
            "I might kill myself",
            "Thinking about suicide",
            "I plan to hurt myself",
            "self-harm tonight",
            "I am not safe right now"
        ]

        for phrase in phrases {
            let state = detector.evaluate(phrase)
            XCTAssertEqual(
                state,
                .immediateConcern,
                "Expected immediate concern for: \(phrase)"
            )
        }
    }

    func testImmediateConcernIsCaseInsensitiveAndNormalizesApostrophes() {
        XCTAssertEqual(detector.evaluate("I'M NOT SAFE"), .immediateConcern)
        XCTAssertEqual(detector.evaluate("I\u{2019}m not safe"), .immediateConcern)
    }

    // MARK: - Elevated / persecutory

    func testElevatedConcernWithoutImmediatePhrases() {
        let elevated = [
            "I don't want to be here",
            "Everyone would be better off without me",
            "I can't go on"
        ]

        for phrase in elevated {
            let state = detector.evaluate(phrase)
            XCTAssertEqual(state, .elevatedConcern, "Expected elevated for: \(phrase)")
            XCTAssertNotEqual(state, .immediateConcern)
        }
    }

    func testPersecutoryLanguageIsElevatedNotImmediate() {
        let phrases = [
            "They are watching me",
            "I feel like I'm being followed",
            "Someone is tracking me",
            "They are plotting against me"
        ]

        for phrase in phrases {
            let state = detector.evaluate(phrase)
            XCTAssertEqual(state, .elevatedConcern, "Expected elevated for: \(phrase)")
            XCTAssertFalse(state.isImmediateConcern)
        }
    }

    // MARK: - Benign / standard

    func testBenignTextStaysStandard() {
        let benign = [
            "",
            "   ",
            "I feel anxious about work tomorrow",
            "A friend said something kind",
            "Need grounding after a long day",
            "Watching a movie tonight",
            "They are watching the game with me"
        ]

        for text in benign {
            XCTAssertEqual(
                detector.evaluate(text),
                .standard,
                "Expected standard for: \(text)"
            )
        }
    }

    // MARK: - No false diagnosis

    func testDisclaimerDoesNotDiagnose() {
        let config = SafetyContentConfiguration.embedded
        let lowered = config.disclaimer.lowercased()
        XCTAssertTrue(lowered.contains("does not diagnose"))
        XCTAssertFalse(lowered.contains("you have schizophrenia"))
        XCTAssertFalse(lowered.contains("you are bipolar"))
    }

    func testSafetyStateSupportiveCopyIsNonClinical() {
        let immediate = SafetyState.immediateConcern.supportiveMessage.lowercased()
        let elevated = SafetyState.elevatedConcern.supportiveMessage.lowercased()

        XCTAssertFalse(immediate.contains("diagnos"))
        XCTAssertFalse(elevated.contains("diagnos"))
        XCTAssertFalse(immediate.contains("psychosis"))
        XCTAssertFalse(elevated.contains("disorder"))
    }

    func testPassthroughDetectorAlwaysStandard() {
        let passthrough = PassthroughSafetyLanguageDetector()
        XCTAssertEqual(passthrough.evaluate("I want to die"), .standard)
    }

    func testNormalizeCollapsesWhitespace() {
        let normalized = LocalSafetyLanguageDetector.normalize("  Want\nTo   Die  ")
        XCTAssertEqual(normalized, "want to die")
    }
}
