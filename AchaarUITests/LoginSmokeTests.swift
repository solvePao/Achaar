import XCTest

@MainActor
final class LoginSmokeTests: XCTestCase {
    func testFeedCommentsOnDevice() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-browsingWasActive", "NO", "-enhancements", "YES", "-startupTab", "home"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 20))
        let infoOK = app.webViews.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "OK")).firstMatch
        if infoOK.waitForExistence(timeout: 5) { infoOK.tap() }
        for _ in 0..<4 {
            let notNow = app.webViews.buttons["Not now"].firstMatch
            let close = app.webViews.descendants(matching: .any).matching(identifier: "Close").firstMatch
            if notNow.exists && notNow.isHittable { notNow.tap() }
            else if close.exists && close.isHittable { close.tap() }
            else { break }
        }
        let home = app.buttons["tab.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20), "Mobile Safari layout must retain Achaar's native tabs.")
        let web = app.webViews.firstMatch
        for attempt in 0..<2 {
            let comments = app.webViews.buttons.matching(NSPredicate(format: "label MATCHES[c] %@", "comments?"))
            XCTAssertTrue(comments.firstMatch.waitForExistence(timeout: 20))
            var visibleComment: XCUIElement?
            for _ in 0..<8 {
                visibleComment = comments.allElementsBoundByIndex.first {
                    $0.isHittable && $0.frame.midY > web.frame.minY + 70 && $0.frame.midY < web.frame.maxY - 130
                }
                if visibleComment != nil { break }
                web.swipeUp()
            }
            guard let comment = visibleComment else { XCTFail("No unobscured feed comment control"); return }
            comment.tap()
            let heading = app.webViews.staticTexts["Comments"].firstMatch
            let opened = heading.waitForExistence(timeout: 15)
            let capture = XCTAttachment(screenshot: app.screenshot())
            capture.name = "Feed comments \(attempt + 1)"; capture.lifetime = .keepAlways; add(capture)
            XCTAssertTrue(opened, "Comment tap must open the mobile Comments page.")
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: home)
            waitForExpectations(timeout: 5)
            XCTAssertFalse(app.buttons["More"].exists)
            XCTAssertFalse(app.buttons["Create"].exists)
            XCTAssertFalse(app.buttons["Activity"].exists)
            let input = app.webViews.textViews.firstMatch
            XCTAssertTrue(input.waitForExistence(timeout: 10))
            input.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            XCTAssertLessThanOrEqual(input.frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
            let keyboard = XCTAttachment(screenshot: app.screenshot())
            keyboard.name = "Comments keyboard \(attempt + 1)"; keyboard.lifetime = .keepAlways; add(keyboard)
            let back = app.webViews.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES[c] %@", "(go )?back")).firstMatch
            XCTAssertTrue(back.exists)
            back.tap()
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: heading)
            waitForExpectations(timeout: 10)
            XCTAssertFalse(app.keyboards.firstMatch.exists)
            XCTAssertTrue(home.waitForExistence(timeout: 10))
        }
    }

    func testReelShareHasNoNativeOverlap() {
        let app = XCUIApplication()
        app.launchArguments = ["-browsingWasActive", "NO"]
        app.launch()
        enableNativeNavigation(in: app)
        let reels = app.buttons["tab.reels"]
        XCTAssertTrue(reels.waitForExistence(timeout: 20))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: reels)
        waitForExpectations(timeout: 20)
        reels.tap()
        let share = app.webViews.buttons.matching(NSPredicate(format: "label MATCHES[c] %@", "share( post)?")).firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 30))
        guard share.exists else { return }
        share.tap()
        let close = app.webViews.descendants(matching: .any).matching(identifier: "Close").firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 15))
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: reels)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.buttons["reels.sound"].exists)
        XCTAssertFalse(app.buttons["More"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Reel share without native overlap"; capture.lifetime = .keepAlways; add(capture)
        let copyLink = app.webViews.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Copy Link")).firstMatch
        XCTAssertTrue(copyLink.exists)
        XCTAssertLessThanOrEqual(copyLink.frame.maxY, app.webViews.firstMatch.frame.maxY)
        app.webViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.70))
            .press(forDuration: 0.1, thenDragTo: app.webViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40)))
        XCTAssertFalse(reels.exists)
        XCTAssertTrue(close.exists)
        let search = app.webViews.textFields.firstMatch
        XCTAssertTrue(search.exists)
        search.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(search.frame.maxY, app.keyboards.firstMatch.frame.minY)
        XCTAssertLessThanOrEqual(search.frame.maxX, app.webViews.firstMatch.frame.maxX)
        let cancelSearch = app.webViews.buttons["Cancel"].firstMatch
        if cancelSearch.exists {
            XCTAssertLessThanOrEqual(cancelSearch.frame.maxX, app.webViews.firstMatch.frame.maxX)
        }
        XCTAssertFalse(reels.exists)
        XCTAssertFalse(app.buttons["reels.sound"].exists)
        let keyboardCapture = XCTAttachment(screenshot: app.screenshot())
        keyboardCapture.name = "Reel share search keyboard"; keyboardCapture.lifetime = .keepAlways; add(keyboardCapture)
        close.tap()
        XCTAssertTrue(reels.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["reels.sound"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
    }

    func testConversationLayoutAndReactionControls() throws {
        guard let threadName = ProcessInfo.processInfo.environment["ACHAAR_TEST_THREAD"],
              !threadName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw XCTSkip("Set ACHAAR_TEST_THREAD to an existing test conversation display name.")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-browsingWasActive", "NO"]
        app.launch(); enableNativeNavigation(in: app)
        let messages = app.buttons["tab.messages"]
        XCTAssertTrue(messages.waitForExistence(timeout: 20))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: messages)
        waitForExpectations(timeout: 20); messages.tap()
        let threadButton = app.webViews.buttons.matching(NSPredicate(format: "label CONTAINS %@", threadName)).firstMatch
        let threadText = app.webViews.staticTexts[threadName].firstMatch
        XCTAssertTrue(threadButton.waitForExistence(timeout: 15) || threadText.exists)
        (threadButton.exists ? threadButton : threadText).tap()
        let back = app.buttons["Back to messages"]
        XCTAssertTrue(back.waitForExistence(timeout: 20))
        let settle = expectation(description: "Conversation layout")
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { settle.fulfill() }
        wait(for: [settle], timeout: 11)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Conversation layout"; capture.lifetime = .keepAlways; add(capture)
        XCTAssertFalse(app.buttons["tab.home"].exists)
        let react = app.buttons["message.react"]
        XCTAssertTrue(react.waitForExistence(timeout: 10))
        react.tap()
        let picker = XCTAttachment(screenshot: app.screenshot())
        picker.name = "Website reaction picker - nothing selected"; picker.lifetime = .keepAlways; add(picker)
        back.tap()
        XCTAssertTrue(messages.waitForExistence(timeout: 15))
        XCTAssertTrue(threadButton.waitForExistence(timeout: 15)); threadButton.tap()
        XCTAssertTrue(react.waitForExistence(timeout: 15))
        app.webViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: 0.56)).press(forDuration: 0.8)
        let heldPicker = XCTAttachment(screenshot: app.screenshot())
        heldPicker.name = "Hold message reaction picker - nothing selected"; heldPicker.lifetime = .keepAlways; add(heldPicker)
        back.tap()
        XCTAssertTrue(messages.waitForExistence(timeout: 15))
        threadButton.tap()
        XCTAssertTrue(back.waitForExistence(timeout: 15))
        let input = app.webViews.textViews.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 15)); input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(input.frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
        let keyboardCapture = XCTAttachment(screenshot: app.screenshot())
        keyboardCapture.name = "Conversation keyboard without overlap"; keyboardCapture.lifetime = .keepAlways; add(keyboardCapture)
        back.tap()
        XCTAssertTrue(messages.waitForExistence(timeout: 15))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
    }

    func testReferenceScreenCaptures() {
        let app = XCUIApplication()
        app.launchArguments = ["-browsingWasActive", "NO"]
        app.launch()
        enableNativeNavigation(in: app)
        for tab in ["home", "messages", "explore", "reels", "profile"] {
            let button = app.buttons["tab.\(tab)"]
            XCTAssertTrue(button.waitForExistence(timeout: 20))
            expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: button)
            waitForExpectations(timeout: 20)
            button.tap()
            expectation(for: NSPredicate(format: "selected == true"), evaluatedWith: button)
            waitForExpectations(timeout: 20)
            XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 20))
            // Allow the responsive web layout to settle before capture.
            let settle = expectation(description: "Web layout settles")
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { settle.fulfill() }
            wait(for: [settle], timeout: 5)
            let capture = XCTAttachment(screenshot: app.screenshot())
            capture.name = "Reference UI - \(tab)"
            capture.lifetime = .keepAlways
            add(capture)
        }
    }

    func testStoryViewerHasNoNativeOverlap() {
        let app = XCUIApplication()
        app.launchArguments = ["-browsingWasActive", "NO"]
        app.launch()
        enableNativeNavigation(in: app)
        let home = app.buttons["tab.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: home)
        waitForExpectations(timeout: 20)
        home.tap()
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.waitForExistence(timeout: 20))
        // Open the second story circle, leaving the signed-in user's creation
        // control untouched. Coordinates are relative to this phone's WebKit frame.
        let settle = expectation(description: "Stories settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { settle.fulfill() }
        wait(for: [settle], timeout: 5)
        web.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: 0.13)).tap()
        let close = app.webViews.descendants(matching: .any).matching(identifier: "Close").firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 15))
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: home)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.buttons["More"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Story viewer without native overlap"; capture.lifetime = .keepAlways; add(capture)
        close.tap()
        XCTAssertTrue(home.waitForExistence(timeout: 15))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testInterruptedLaunchRecovery() {
        let app = XCUIApplication()
        app.launchArguments = ["-browsingWasActive", "YES", "-browsingInterruptedStarts", "1"]
        app.launch()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Browsing stopped unexpectedly")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Retry"].exists)
        XCTAssertFalse(app.buttons["Open Instagram in Safari"].exists)
        XCTAssertFalse(app.webViews.firstMatch.exists, "Recovery should prevent loading the failing page until Retry.")
        XCTAssertFalse(app.buttons["tab.home"].exists, "Recovery should show its own actions instead of inactive navigation.")
        app.terminate()
    }

    func testNativeProfileAndMessageShortcuts() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-browsingWasActive", "NO"]
        app.launch()
        enableNativeNavigation(in: app)
        let home = app.buttons["tab.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: home)
        waitForExpectations(timeout: 20)
        openMenu(in: app)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["settings.warmMessages"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Observed cached files"].exists)
        app.buttons["Done"].tap()
        openMenu(in: app)
        app.buttons["Message shortcuts"].tap()
        app.buttons["New message"].tap()
        XCTAssertTrue(app.webViews.buttons["Chat"].firstMatch.waitForExistence(timeout: 15), "Native message shortcut should open the blank composer.")
        XCTAssertFalse(app.alerts["Achaar"].exists)
        let recipientSearch = app.webViews.textFields.firstMatch
        if recipientSearch.exists {
            recipientSearch.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["tab.home"].exists, "Native navigation should hide for the message keyboard.")
            XCTAssertFalse(app.buttons["More"].exists, "Floating controls should not cover the composer.")
        }
        let close = app.webViews.buttons["Close"].firstMatch
        if close.exists { close.tap() }
        else if app.webViews.images["Close"].firstMatch.exists { app.webViews.images["Close"].firstMatch.tap() }
        // No form is edited, no recipient is selected, and nothing is sent.
        app.buttons["tab.home"].tap()
        XCTAssertEqual(app.state, .runningForeground)
    }

    private func openMenu(in app: XCUIApplication) {
        let more = app.buttons["More"]
        if more.exists { more.tap(); return }
        let profile = app.buttons["tab.profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 20))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: profile)
        waitForExpectations(timeout: 20)
        profile.press(forDuration: 1.0)
    }

    private func enableNativeNavigation(in app: XCUIApplication) {
        openMenu(in: app)
        app.buttons["Settings"].tap()
        let enhancements = app.switches["settings.enhancements"].firstMatch
        XCTAssertTrue(enhancements.waitForExistence(timeout: 5))
        if enhancements.value as? String == "0" {
            enhancements.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        XCTAssertEqual(enhancements.value as? String, "1")
        app.buttons["Done"].tap()
        app.terminate()
        app.launch()
    }

    func testCreationThroughOriginalWebControl() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-browsingWasActive", "NO"]
        app.launch()
        enableNativeNavigation(in: app)
        let home = app.buttons["tab.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: home)
        waitForExpectations(timeout: 20)
        openMenu(in: app)
        app.buttons["Browser controls"].tap()
        app.buttons["Original web interface"].tap()
        defer {
            openMenu(in: app)
            app.buttons["Settings"].tap()
            let enhancements = app.switches["settings.enhancements"].firstMatch
            if enhancements.waitForExistence(timeout: 5), enhancements.value as? String == "0" {
                enhancements.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            }
            app.buttons["Done"].tap()
        }
        let icon = app.webViews.images["New post"].firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 10))
        guard icon.exists else { return }
        icon.tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Original creation control result (no media chosen)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertTrue(app.webViews.staticTexts["Post"].firstMatch.waitForExistence(timeout: 10))
    }

    func testSignedInToolbarMapping() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-browsingWasActive", "NO"]
        app.launch()
        enableNativeNavigation(in: app)
        let home = app.buttons["tab.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: home)
        waitForExpectations(timeout: 20)
        openMenu(in: app)
        app.buttons["Activity"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Notifications"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(app.alerts["Achaar"].exists, "Activity should map to Instagram's control.")
        home.tap()
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: home)
        waitForExpectations(timeout: 20)
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testSignedInScrollingAndNativeNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-browsingWasActive", "NO"]
        app.launch()
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 20))
        let ready = NSPredicate(format: "enabled == true")
        expectation(for: ready, evaluatedWith: app.buttons["tab.home"])
        waitForExpectations(timeout: 20)
        XCTAssertFalse(app.navigationBars["Home"].exists, "The wrapper title bar must be removed.")
        let navigation = XCTAttachment(screenshot: app.screenshot())
        navigation.name = "Signed-in native navigation"
        navigation.lifetime = .keepAlways
        add(navigation)
        // Operate only navigation controls; never enter credentials, interact
        // with posts, submit composers, or inspect private message contents.
        for _ in 0..<8 {
            web.swipeUp()
            XCTAssertEqual(app.state, .runningForeground)
        }
        let start = web.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        let end = web.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.25))
        start.press(forDuration: 0.15, thenDragTo: end)
        for tab in ["explore", "reels", "messages", "profile", "home"] {
            let button = app.buttons["tab.\(tab)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
            XCTAssertTrue(web.waitForExistence(timeout: 15))
            expectation(for: NSPredicate(format: "selected == true"), evaluatedWith: button)
            waitForExpectations(timeout: 15)
            XCTAssertEqual(app.state, .runningForeground)
        }
        // Return to the already-loaded inbox and back to the retained feed.
        for tab in ["messages", "home", "messages", "home"] {
            app.buttons["tab.\(tab)"].tap()
            XCTAssertEqual(app.state, .runningForeground)
            expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["tab.\(tab)"])
            waitForExpectations(timeout: 15)
        }
    }

    func testLoginControlDoesNotCrashApp() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-browsingWasActive", "NO"]
        app.launch()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 20))
        let loginButton = app.webViews.buttons.matching(NSPredicate(format: "label MATCHES[c] %@", "log\\s*in")).firstMatch
        let loginLink = app.webViews.links.matching(NSPredicate(format: "label MATCHES[c] %@", "log\\s*in")).firstMatch
        let buttonExists = loginButton.waitForExistence(timeout: 30)
        let control = buttonExists ? loginButton : loginLink
        XCTAssertTrue(control.waitForExistence(timeout: 10), "Instagram must expose its signed-out login control for this smoke test.")
        guard control.exists else { return }
        control.tap()
        // Wait for the next UI query through XCTest, rather than submitting credentials.
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.waitForExistence(timeout: 10))
        XCTAssertEqual(app.state, .runningForeground, "Tapping Log in must keep Achaar running.")
        guard app.state == .runningForeground else { return }
        XCTAssertTrue(web.secureTextFields.firstMatch.waitForExistence(timeout: 20),
                      "Log in should open Instagram's password form.")
        let username = web.textFields.firstMatch
        if username.exists {
            username.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Login page after tap (no credentials)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
