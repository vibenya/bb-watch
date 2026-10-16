import XCTest

/// Drives the full watch scenario against a live BB for usability recording.
/// Env: BB_PAIRING_CODE (pair if offline), BB_THREAD_TITLE (thread to select on the Threads page).
final class ScenarioUITests: XCTestCase {
    let app = XCUIApplication()
    let start = Date()

    func log(_ step: String) {
        NSLog("UX|t=%07.2f|%@", Date().timeIntervalSince(start), step)
    }
    func dump(_ screen: String) {
        print("UXTREE|\(screen)|BEGIN")
        for line in app.debugDescription.split(separator: "\n") { print("UXTREE|\(screen)|\(line)") }
        print("UXTREE|\(screen)|END")
    }
    /// watchOS exposes List rows as cells or buttons whose label starts with the row title.
    func row(_ title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "(elementType == 75 OR elementType == 9) AND label BEGINSWITH %@", title)).firstMatch
    }
    @discardableResult
    func waitFor(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 20) -> Bool {
        let t = Date()
        let ok = element.waitForExistence(timeout: timeout)
        log("wait \(label) -> \(ok ? "ok" : "MISSING") in \(String(format: "%.2f", Date().timeIntervalSince(t)))s")
        return ok
    }
    func tap(_ element: XCUIElement, _ label: String) {
        var tries = 0
        _ = element.waitForExistence(timeout: 8)
        while !(element.exists && element.isHittable) && tries < 12 { crown(0.25); settle(0.3); tries += 1; log("crown for \(label)") }
        waitFor(element, label, timeout: 5)
        element.tap(); log("tap \(label)")
    }
    func back() {
        let button = app.navigationBars.buttons.firstMatch
        if button.waitForExistence(timeout: 3) { button.tap() } else { app.swipeRight() }
        log("back")
    }
    /// Small scroll standing in for the Digital Crown (XCUITest has no crown API on watchOS).
    func crown(_ delta: Double) {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: delta > 0 ? 0.75 : 0.35))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: delta > 0 ? 0.75 - 0.4 * delta : 0.35 - 0.4 * delta))
        from.press(forDuration: 0.05, thenDragTo: to)
    }
    func settle(_ seconds: TimeInterval) { Thread.sleep(forTimeInterval: seconds) }

    /// The big mood word on the stage (or the empty-stage hint when no thread is selected).
    func mood(_ words: [String]) -> XCUIElement {
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: words.map { NSPredicate(format: "label ==[c] %@", $0) })
        return app.staticTexts.matching(predicate).firstMatch
    }
    func anyMood() -> XCUIElement { mood(["READY", "WORKING", "NEEDS YOU", "DONE", "FAILED", "SENDING", "OFFLINE"]) }
    func closeSheet() {
        let close = app.buttons["Close"].firstMatch
        if close.waitForExistence(timeout: 3) { close.tap() } else { app.swipeDown() }
        log("close sheet")
    }

    /// Three pages: Record ← Stage → Threads. Drives the live BB without the microphone.
    func testFullScenario() throws {
        let env = ProcessInfo.processInfo.environment
        let code = env["BB_PAIRING_CODE"] ?? ""
        let wantedTitle = env["BB_THREAD_TITLE"] ?? ""
        log("code present: \(!code.isEmpty)")
        app.launch(); log("launched")

        // 1. Stage, pairing if needed.
        waitFor(anyMood(), "stage word", timeout: 30)
        settle(2); dump("stage-launch")
        if !code.isEmpty && mood(["OFFLINE"]).exists {
            app.swipeLeft(); settle(1.5)
            tap(row("Connect BB"), "Connect BB row")
            let field = app.textFields["Pairing code"]
            tap(field, "pairing field"); settle(1.5)
            app.typeText(code); log("typed code")
            settle(0.5); dump("pairing-keyboard")
            for done in ["Done", "Готово"] where app.buttons[done].exists { app.buttons[done].tap(); log("tap \(done)"); break }
            settle(1)
            tap(app.buttons["Connect"].firstMatch, "Connect")
            waitFor(app.staticTexts["Connected"], "Connected", timeout: 40)
            settle(1); dump("settings-connected"); closeSheet(); settle(1)
            app.swipeRight(); settle(1.5)
        }

        // 2. Threads page: pick the test thread.
        app.swipeLeft(); settle(1.5); log("threads page")
        let rows = app.cells
        waitFor(rows.element(boundBy: 1), "thread rows", timeout: 30)
        settle(1.5); dump("threads")
        crown(1.0); settle(0.8); crown(-1.0); settle(0.8); log("scrolled threads")
        let target: XCUIElement
        if wantedTitle.isEmpty { target = rows.element(boundBy: 2) } else { target = row(wantedTitle) }
        tap(target, wantedTitle.isEmpty ? "second chat" : "chat \(wantedTitle)")
        waitFor(anyMood(), "stage after pick", timeout: 15)
        if !wantedTitle.isEmpty {
            waitFor(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", wantedTitle)).firstMatch, "stage shows thread", timeout: 10)
        }
        settle(2); dump("stage-picked")

        // 3. Send the seeded transcript-only draft to the current thread.
        app.swipeLeft(); settle(1.5)
        let recordings = row("Recordings")
        for _ in 0..<60 where !(recordings.exists && recordings.isHittable) { app.swipeUp(velocity: .fast) }
        dump("threads-footer")
        tap(recordings, "Recordings")
        settle(1.5); dump("recordings-list")
        tap(row("00:14"), "newest recording")  // sheet rows start with the duration; list is newest first
        waitFor(row("Send"), "draft view"); settle(1.5); dump("draft")
        tap(row("Send"), "Send")
        let sendT = Date()
        // The sheet stays open after Send; close it and return to the stage to watch.
        settle(0.5); dump("draft-sent")
        closeSheet(); settle(0.5)
        if !anyMood().exists { closeSheet() }
        app.swipeRight(); settle(1)
        let sawSending = waitFor(mood(["SENDING"]), "SENDING", timeout: 15)
        if sawSending { dump("stage-sending") }
        let sawWorking = waitFor(mood(["WORKING"]), "WORKING", timeout: 60)
        if sawWorking { settle(1); dump("stage-working") }
        let done = waitFor(mood(["DONE"]), "DONE", timeout: 120)
        log("send-to-done \(String(format: "%.1f", Date().timeIntervalSince(sendT)))s done=\(done)")
        settle(2); dump("stage-done")
        XCTAssertTrue(done, "agent reply never reached DONE")

        // 4. Full thread sheet.
        app.tap(); log("tap stage")
        waitFor(app.buttons["Listen"].firstMatch, "thread sheet", timeout: 10)
        settle(1.5); dump("thread-sheet")
        let listen = app.buttons["Listen"].firstMatch
        if listen.exists { listen.tap(); log("tap Listen"); settle(3); dump("thread-sheet-playing") }
        closeSheet(); settle(1.5)

        // 5. Record page, no recording.
        app.swipeRight(); settle(2.5); log("record page"); dump("record")
        app.swipeLeft(); settle(1.5); log("back on stage")
        waitFor(anyMood(), "stage again", timeout: 10)
        log("done")
    }

    /// Walks the three-page UI for screenshots; no recording, no sends.
    func testTour() throws {
        app.launch(); log("launched"); settle(5); dump("stage")
        app.swipeRight(); settle(3); log("record page"); dump("record")
        app.swipeLeft(); settle(1); app.swipeLeft(); settle(3); log("threads page"); dump("threads")
        app.swipeUp(); settle(2); app.swipeDown(); settle(1)
        let rows = app.cells
        if rows.count > 2 { rows.element(boundBy: 2).tap(); log("tap thread 2"); settle(5); dump("stage-2") }
        app.tap(); settle(3); log("full thread sheet"); dump("thread-sheet")
        app.swipeDown(); settle(2)
        if app.buttons["Close"].firstMatch.exists { app.buttons["Close"].firstMatch.tap() }
        settle(2); log("done")
    }
}
