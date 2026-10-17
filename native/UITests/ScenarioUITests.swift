import XCTest

/// Explicit local simulator fixtures never authenticate, record AVAudioEngine input,
/// or send prompts. Each launch uses a separate temporary durable store.
final class ScenarioUITests: XCTestCase {
    let app = XCUIApplication()
    override func setUp() { continueAfterFailure = false }
    func launch(_ scenario: String) {
        app.terminate()
        app.launchEnvironment["BB_UI_FIXTURE"] = scenario
        app.launch()
        XCTAssertTrue(app.buttons["Choose thread"].waitForExistence(timeout: 15))
    }
    func screenshot(_ name: String) {
        // Native sheet/symbol transitions can finish after the accessibility tree updates.
        Thread.sleep(forTimeInterval: 0.35)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func tap(_ label: String) {
        let element = app.buttons[label].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 8), label)
        if !element.isHittable { app.swipeUp() }
        element.tap()
    }
    func row(_ prefix: String) -> XCUIElement {
        let matches = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
        return matches.allElementsBoundByIndex.first(where: { $0.isHittable }) ?? matches.firstMatch
    }
    func assertButton(_ name: String) { XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 8), name) }

    func testCaptureAndRecipient() {
        launch("recording")
        assertButton("Pause recording")
        screenshot("capture")
        tap("Choose thread")
        XCTAssertTrue(row("Release notes").waitForExistence(timeout: 8))
        row("Release notes").tap()
        assertButton("Pause recording")
        XCTAssertTrue((app.buttons["Choose thread"].value as? String)?.contains("Release notes") == true)
        tap("Pause recording")
        assertButton("Resume recording")
        screenshot("paused-retargeted")
        tap("Choose thread")
        tap("Return to recorder")
        assertButton("Resume recording") // Navigation must never start capture.
        tap("Resume recording")
        assertButton("Pause recording")
        tap("Send recording")
        assertButton("Record") // A queued request must not block capture.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Transcribing'")).firstMatch.waitForExistence(timeout: 8))
        screenshot("processing")
        tap("Record")
        assertButton("Pause recording")
        tap("Pause recording")
        tap("Close recording, keep saved audio")
        assertButton("Record")
        tap("Recordings")
        assertButton("Return to recorder")
        screenshot("history")
        XCTAssertTrue(row("Check the reply").waitForExistence(timeout: 8))
    }
    func testUnsentSelectionDoesNotChangeObservation() {
        launch("paused")
        tap("Choose thread")
        row("Release notes").tap()
        tap("Close recording, keep saved audio")
        XCTAssertTrue((app.buttons["Choose thread"].value as? String)?.contains("Watch sync") == true)
        tap("Recordings")
        XCTAssertTrue(row("Check the reply").waitForExistence(timeout: 8))
        row("Check the reply").tap()
        XCTAssertTrue(app.staticTexts["Release notes"].exists)
        screenshot("saved-retargeted")
    }
    func testNewContextAndToolbar() {
        launch("working")
        tap("Choose thread"); screenshot("threads")
        tap("New")
        XCTAssertTrue(app.buttons["Project selector"].waitForExistence(timeout: 8))
        screenshot("new")
        tap("Project selector")
        tap("Website")
        tap("Model selector")
        XCTAssertTrue(row("Project default").waitForExistence(timeout: 8))
        screenshot("models-default")
        tap("Return to recorder")
        assertButton("Record")
        XCTAssertFalse(app.buttons["Pause recording"].exists)
        tap("Record")
        assertButton("Pause recording")
        XCTAssertTrue(app.frame.contains(app.buttons["Send recording"].frame), "New recording must keep Send fully visible")
        screenshot("new-capture")
    }
    func testQuestionUndo() {
        launch("question")
        XCTAssertTrue(app.staticTexts["Which version should I keep?"].waitForExistence(timeout: 8))
        screenshot("question")
        tap("Keep the simple version")
        assertButton("Undo")
        screenshot("undo")
        tap("Undo")
        assertButton("Keep the simple version")
    }
    func testPendingAnswerDoesNotReplaceNewDelivery() {
        launch("question")
        tap("Keep the simple version")
        assertButton("Undo")
        tap("Choose thread"); tap("New")
        tap("Record"); tap("Send recording")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Transcribing'")).firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Undo"].exists)
        XCTAssertTrue((app.buttons["Choose thread"].value as? String)?.contains("Transcribing") == true)
        screenshot("new-delivery-with-previous-answer")
        tap("Choose thread"); row("Watch sync").tap()
        assertButton("Undo") // Selecting New did not delete or answer the prior question.
    }
    func testContinuousNewRequestLifecycle() {
        launch("lifecycle")
        tap("Record")
        assertButton("Pause recording")
        tap("Send recording")
        let states = ["Transcribing", "Sending transcript", "Accepted by BB", "Checking the requested changes.", "The requested changes are ready for review."]
        for (index, state) in states.enumerated() {
            let content = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", state)).firstMatch
            XCTAssertTrue(content.waitForExistence(timeout: 8), state)
            assertButton("Record")
            XCTAssertFalse(app.buttons["Project selector"].exists)
            screenshot("lifecycle-\(index)")
            if index < states.count - 1 {
                app.swipeUp()
                tap("Advance fixture")
                app.swipeDown(); app.swipeDown()
            }
        }
        XCTAssertTrue((app.buttons["Choose thread"].value as? String)?.contains("New request") == true)
    }
    func testSwipeChooserAndDismiss() {
        launch("working")
        app.swipeLeft()
        XCTAssertTrue(app.buttons["New"].waitForExistence(timeout: 8))
        // System dismiss gesture preserves current context.
        app.swipeDown()
        if app.buttons["Return to recorder"].exists { tap("Return to recorder") }
        assertButton("Choose thread")
        XCTAssertTrue((app.buttons["Choose thread"].value as? String)?.contains("Watch sync") == true)
    }
    func advanceFixture() {
        app.swipeUp(); app.swipeUp()
        tap("Advance fixture")
        app.swipeDown(); app.swipeDown(); app.swipeDown()
    }
    func testFollowupCaptureResolvesToCreatedThread() {
        launch("lifecycle")
        tap("Record"); tap("Send recording")
        tap("Record"); tap("Pause recording")
        XCTAssertFalse(app.buttons["Project selector"].exists)
        advanceFixture(); advanceFixture()
        XCTAssertTrue((app.buttons["Choose thread"].value as? String)?.contains("New request") == true)
        assertButton("Resume recording")
        screenshot("followup-resolved")
        tap("Send recording")
        assertButton("Record")
        XCTAssertTrue((app.buttons["Choose thread"].value as? String)?.contains("New request") == true)
    }
    func testLateCreateReceiptDoesNotStealSelection() {
        launch("lifecycle")
        tap("Record"); tap("Send recording")
        tap("Choose thread"); row("Release notes").tap()
        advanceFixture(); advanceFixture()
        XCTAssertTrue((app.buttons["Choose thread"].value as? String)?.contains("Release notes") == true)
        screenshot("late-create-selection-preserved")
    }
    func testLargeTextAndReduceMotion() {
        app.launchEnvironment["BB_UI_ACCESSIBILITY"] = "1"
        defer { app.launchEnvironment["BB_UI_ACCESSIBILITY"] = nil }
        launch("question")
        XCTAssertTrue(app.staticTexts["Which version should I keep?"].waitForExistence(timeout: 8))
        screenshot("large-question-reduce-motion")
        tap("Show the detailed version")
        tap("Undo")
        assertButton("Keep the simple version")
        screenshot("large-question-after-undo")
    }
    func testTour() {
        for scenario in ["working", "result", "loading", "stale", "offline", "waiting", "agent-error", "queued", "transcribing", "sending", "unknown", "failed", "unsupported"] {
            launch(scenario)
            XCTAssertTrue(app.buttons["Record"].exists || app.buttons["Record voice"].exists)
            screenshot(scenario)
            if scenario == "unknown" {
                XCTAssertFalse(app.buttons["Send recording"].exists)
                tap("Recordings")
                row("Check thread switching").tap()
                XCTAssertFalse(app.buttons["Send recording"].exists)
                screenshot("unknown-detail")
            }
        }
    }
}
