import XCTest
@testable import OnAir

final class ImportedRadioGamesTests: XCTestCase {
    func testChessOpeningMoveCountsAndUndo() {
        let game = ChessGame()
        let first = (0..<64).flatMap { from in game.legalMoves(from: from).map { (from, $0) } }
        XCTAssertEqual(first.count, 20)
        var second = 0
        for (from, to) in first {
            var next = game
            XCTAssertTrue(next.move(from: from, to: to))
            second += (0..<64).reduce(0) { $0 + next.legalMoves(from: $1).count }
            next.undo(); XCTAssertEqual(next, game)
        }
        XCTAssertEqual(second, 400)
    }
    func testGomokuWinUndoAndCodable() throws {
        var game = GomokuGame()
        for column in 0..<4 { game.play(row: 7, column: column); game.play(row: 8, column: column) }
        game.play(row: 7, column: 4)
        XCTAssertEqual(game.winner, 1)
        XCTAssertEqual(try JSONDecoder().decode(GomokuGame.self, from: JSONEncoder().encode(game)), game)
        game.undo(); XCTAssertNil(game.winner); XCTAssertEqual(game.currentPlayer, 1)
    }
    func testSudokuCluesNotesAndCompletion() throws {
        var game = SudokuGame()
        let blank = try XCTUnwrap(game.puzzle.firstIndex(of: 0))
        let clue = try XCTUnwrap(game.puzzle.firstIndex(where: { $0 != 0 }))
        let original = game.board[clue]
        game.set(0, at: clue); XCTAssertEqual(game.board[clue], original)
        game.toggleNote(3, at: blank); XCTAssertTrue(game.notes[blank].contains(3))
        game.set(game.solution[blank], at: blank); XCTAssertTrue(game.notes[blank].isEmpty)
        for index in game.puzzle.indices where game.puzzle[index] == 0 { game.set(game.solution[index], at: index) }
        XCTAssertTrue(game.isComplete)
        for row in 0..<9 { XCTAssertEqual(Set(game.solution[(row*9)..<(row*9+9)]), Set(1...9)) }
    }
}
