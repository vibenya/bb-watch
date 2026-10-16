import XCTest

/// Drives the full watch scenario against a live BB for usability recording.
/// Pairing code comes from the BB_PAIRING_CODE environment variable; project name from BB_PROJECT_NAME.
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

    func testFullScenario() throws {
        let env = ProcessInfo.processInfo.environment
        let code = env["BB_PAIRING_CODE"] ?? ""
        log("code present: \(!code.isEmpty)")
        let projectName = env["BB_PROJECT_NAME"] ?? "bb-watch"
        app.launch(); log("launched")
        waitFor(row("Record"), "home Record")
        settle(1); dump("home-unpaired")

        // 1. Pair with live BB.
        crown(0.7); settle(0.5); dump("home-scrolled"); let connect = row("Connect BB").exists ? row("Connect BB") : row("Settings")
        tap(connect, "Settings/Connect")
        settle(1); dump("settings")
        if !code.isEmpty && !app.staticTexts["BB connected"].exists {
            let field = app.textFields["Pairing code"]
            tap(field, "pairing field")
            settle(1.5)
            app.typeText(code); log("typed code")
            settle(0.5); dump("pairing-keyboard")
            for done in ["Done", "Готово"] where app.buttons[done].exists { app.buttons[done].tap(); log("tap \(done)"); break }
            settle(1)
            tap(app.buttons["Connect BB"], "Connect BB button")
            waitFor(app.staticTexts["BB connected"], "BB connected", timeout: 40)
        }
        settle(1); dump("settings-connected")
        back()

        // 2. Home after sync.
        waitFor(row("Record"), "home")
        settle(8); crown(1.0); settle(0.5)
        log("home synced: \(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Updated'")).firstMatch.exists)")
        dump("home-paired"); crown(-1.0); settle(0.5)

        // 3. Chats list and a thread.
        tap(row("Chats"), "Chats")
        waitFor(app.navigationBars.staticTexts["Chats"], "chats title")
        waitFor(app.cells.element(boundBy: 1), "chat rows", timeout: 30)
        settle(1.5); dump("chats")
        app.swipeUp(); settle(1); app.swipeUp(); settle(1); log("scrolled chats")
        app.swipeDown(); app.swipeDown(); settle(1)
        let firstChat = app.cells.element(boundBy: 0)
        tap(firstChat, "first chat")
        waitFor(row("Record reply"), "thread view")
        settle(2); dump("thread")
        app.swipeUp(); settle(1); app.swipeUp(); settle(1); log("scrolled thread")
        back(); settle(0.5); back(); settle(0.5)

        // 4. Record → send → new thread in project. The watch simulator aborts on AVAudioEngine input,
        // so with BB_SKIP_RECORD the seeded transcript-only draft from Recordings is sent instead.
        if env["BB_SKIP_RECORD"] == nil {
            tap(row("Record"), "Record")
            waitFor(app.buttons["Send"], "recording screen")
            log("recording-started"); settle(1); dump("recording")
            settle(9)
            tap(app.buttons["Pause"], "Pause"); settle(1.5); dump("paused")
            tap(app.buttons["Resume"], "Resume"); settle(4)
            tap(app.buttons["Send"], "Send")
        } else {
            tap(row("Recordings"), "Recordings")
            waitFor(app.navigationBars.staticTexts["Recordings"], "recordings title")
            settle(1.5); dump("recordings-list")
            tap(app.cells.element(boundBy: 0), "newest recording")
            waitFor(row("Send"), "draft view"); settle(1.5); dump("draft")
            tap(row("Send"), "Send")
        }
        waitFor(row("New thread"), "recipient picker")
        settle(1.5); dump("recipients")
        app.swipeUp(); settle(1); app.swipeDown(); settle(0.5)
        tap(row("New thread"), "New thread")
        waitFor(app.buttons.element(boundBy: 1), "projects")
        settle(1); dump("projects")
        let project = app.buttons[projectName]
        if project.waitForExistence(timeout: 3) { project.tap(); log("tap project \(projectName)") }
        else { app.buttons.element(boundBy: 1).tap(); log("tap first project") }
        waitFor(app.staticTexts["Queued"].exists ? app.staticTexts["Queued"] : app.staticTexts["Transcribing"], "sending", timeout: 15)
        settle(0.5); dump("draft-sending")
        waitFor(app.staticTexts["Accepted by BB"], "accepted", timeout: 90)
        settle(1); dump("draft-accepted")

        // 5. Watch the agent reply.
        tap(row("Open thread"), "Open thread")
        waitFor(row("Record reply"), "new thread")
        var replyFound = false
        for i in 0..<12 {
            settle(8)
            if app.buttons["Refresh"].exists { app.buttons["Refresh"].tap() }
            log("poll reply \(i)")
            if app.staticTexts["Agent"].waitForExistence(timeout: 4) { replyFound = true; break }
        }
        log("agent reply found: \(replyFound)")
        settle(1); dump("thread-after-send")
        if replyFound {
            tap(app.cells.containing(.staticText, identifier: "Agent").firstMatch, "agent reply")
            waitFor(app.buttons["Listen"], "reply view")
            settle(1); dump("reply")
            tap(app.buttons["Listen"], "Listen"); settle(6)
            if app.buttons["Pause"].exists { app.buttons["Pause"].tap(); log("pause playback") }
            back(); settle(0.5)
        }
        back(); settle(0.5)
        if app.buttons["Back"].exists || app.navigationBars.buttons.firstMatch.exists { back(); settle(0.5) }

        // 6. Remaining home sections.
        if waitFor(row("Needs You"), "home again", timeout: 10) {
            tap(row("Needs You"), "Needs You"); settle(2); dump("needs-you"); back(); settle(0.5)
            tap(row("Recordings"), "Recordings"); settle(2); dump("recordings"); back(); settle(0.5)
        }
        log("done")
    }
}
