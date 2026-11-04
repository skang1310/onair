import XCTest

@MainActor final class RadioExtrasFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testNightRadioAndSharePoster() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-showNight"]; app.launch()
        XCTAssertTrue(app.staticTexts["NIGHT RADIO"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["재생 또는 정지"].exists)
        app.buttons["닫기"].tap()
        XCTAssertTrue(app.tabBars.buttons["홈"].exists)
        app.terminate()
        app.launchArguments = ["-showShare"]; app.launch()
        XCTAssertTrue(app.navigationBars["오늘의 주파수"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["주파수 카드 공유"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "주파수 포스터"; attachment.lifetime = .keepAlways; add(attachment)
        app.terminate()
    }
    func testWakeEditor() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-showFavorites"]; app.launch()
        let wake = app.buttons["기상 라디오"]
        for _ in 0..<4 { if wake.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(wake.waitForExistence(timeout: 8)); wake.tap()
        XCTAssertTrue(app.navigationBars["기상 라디오"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["기상 알람 저장"].exists)
        app.terminate()
    }
}
