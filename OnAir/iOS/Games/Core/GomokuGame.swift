import Foundation

struct GomokuGame: Codable, Sendable, Equatable {
    private(set) var board = Array(repeating: 0, count: 225)
    private(set) var currentPlayer = 1
    private(set) var winner: Int?
    var isDraw: Bool { winner == nil && !board.contains(0) }
    private var history: [Int] = []
    mutating func play(row: Int, column: Int) {
        guard (0..<15).contains(row), (0..<15).contains(column), winner == nil, !isDraw else { return }
        let index = row * 15 + column
        guard board[index] == 0 else { return }
        board[index] = currentPlayer; history.append(index)
        for (dr, dc) in [(1,0),(0,1),(1,1),(1,-1)] {
            var count = 1
            for sign in [-1,1] {
                var r = row + dr * sign, c = column + dc * sign
                while (0..<15).contains(r), (0..<15).contains(c), board[r*15+c] == currentPlayer {
                    count += 1; r += dr * sign; c += dc * sign
                }
            }
            if count >= 5 { winner = currentPlayer }
        }
        if winner == nil { currentPlayer = 3-currentPlayer }
    }
    var validSession: Bool {
        guard board.count == 225, history.count <= 225, Set(history).count == history.count,
              history.allSatisfy({ (0..<225).contains($0) }), [1,2].contains(currentPlayer) else { return false }
        var replay = GomokuGame()
        for index in history { replay.play(row:index / 15,column:index % 15) }
        return replay.board == board && replay.currentPlayer == currentPlayer && replay.winner == winner && replay.moves == history
    }
    var lastMove: Int? { history.last }
    var moveCount: Int { history.count }
    var moves: [Int] { history }
    mutating func undo() { guard let i = history.popLast() else { return }; currentPlayer = board[i]; board[i] = 0; winner = nil }
    mutating func reset() { self = GomokuGame() }
}
