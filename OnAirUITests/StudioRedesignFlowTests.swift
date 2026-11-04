import XCTest

@MainActor final class StudioRedesignFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let item = XCTAttachment(screenshot: app.screenshot()); item.name = name; item.lifetime = .keepAlways; add(item)
    }
    func testRadioSearchFavoriteAndDarkAppearance() throws {
        let app = XCUIApplication(); app.launchArguments = ["-appearance", "light"]; app.launch()
        XCTAssertTrue(app.buttons["hero-play"].waitForExistence(timeout: 12))
        screenshot(app, "01-radio-home")
        app.buttons["탐색"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 8)); search.tap(); search.typeText("CBS\n")
        XCTAssertTrue(app.buttons["station-play-cbsmusic"].waitForExistence(timeout: 8))
        screenshot(app, "02-search-cbs")
        let favorite = app.buttons["station-favorite-cbsmusic"]
        if favorite.value as? String != "저장됨" { favorite.tap() }
        app.buttons["보관함"].tap()
        XCTAssertTrue(app.buttons["station-play-cbsmusic"].waitForExistence(timeout: 6))
        screenshot(app, "03-library")
        app.terminate()
        app.launchArguments = ["-appearance", "dark"]; app.launch()
        XCTAssertTrue(app.buttons["hero-play"].waitForExistence(timeout: 10)); screenshot(app, "04-dark-home")
    }
    func testAllThreeImportedGamesArePlayable() throws {
        let app = XCUIApplication(); app.launchArguments = ["-showGames", "-appearance", "light", "--test-direct-board-input", "--reset-radio-games"]; app.launch()
        XCTAssertTrue(app.buttons["game-open-체스"].waitForExistence(timeout: 12)); screenshot(app, "05-games")
        app.buttons["game-open-체스"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["chess.status"].waitForExistence(timeout: 10)); screenshot(app, "06-chess")
        app.buttons["chess.cell.6.4"].tap(); app.buttons["chess.cell.4.4"].tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "chess.status").matching(NSPredicate(format: "label CONTAINS %@", "흑")).firstMatch.exists)
        app.buttons["game-back"].tap()
        XCTAssertTrue(app.buttons["game-open-오목"].waitForExistence(timeout: 6)); app.buttons["game-open-오목"].tap()
        let cell = app.buttons["gomoku.cell.7.7"]
        XCTAssertTrue(cell.waitForExistence(timeout: 8)); cell.tap(); screenshot(app, "07-gomoku-move")
        app.buttons["game-back"].tap()
        XCTAssertTrue(app.buttons["game-open-스도쿠"].waitForExistence(timeout: 6)); app.buttons["game-open-스도쿠"].tap()
        let square = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "sudoku.cell.", "빈 칸")).firstMatch
        XCTAssertTrue(square.waitForExistence(timeout: 8)); let squareID = square.identifier; square.tap()
        XCTAssertTrue(app.buttons["sudoku.number.1"].exists); app.buttons["sudoku.number.1"].tap()
        XCTAssertTrue(app.buttons[squareID].label.hasSuffix(", 1")); screenshot(app, "08-sudoku-entry")
    }
}
