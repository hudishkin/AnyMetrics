import XCTest

final class OnboardingTests: XCTestCase {
    func testSkipAndAddWidgetFlow() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "NO", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()

        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        skip.tap()
        waitForDisappearance(skip)
        XCTAssertFalse(app.staticTexts["widgetGuide.title"].exists)

        app.terminate()
        app.launch()
        for _ in 0..<3 {
            let next = app.buttons["onboarding.next"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            next.tap()
        }

        let addWidget = app.buttons["onboarding.addWidget"]
        XCTAssertTrue(addWidget.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["onboarding.starter.title"].exists)
        XCTAssertTrue(app.buttons["onboarding.chooseFromGallery"].exists)
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Onboarding - Picture of the Day"
        preview.lifetime = .keepAlways
        add(preview)

        addWidget.tap()
        let guide = app.staticTexts["widgetGuide.title"]
        XCTAssertTrue(guide.waitForExistence(timeout: 10))
        XCTAssertFalse(addWidget.exists)
        XCTAssertFalse(app.alerts.element.exists)
        let instructions = XCTAttachment(screenshot: app.screenshot())
        instructions.name = "Onboarding - Add Widget Instructions"
        instructions.lifetime = .keepAlways
        add(instructions)

        let done = app.buttons["widgetGuide.done"]
        if !done.isHittable { app.swipeUp() }
        done.tap()
        waitForDisappearance(guide)
    }

    private func waitForDisappearance(_ element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
}
