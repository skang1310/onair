import Foundation

enum ComputerDifficulty: String, CaseIterable, Sendable {
    case easy, medium, hard
    var title: String { switch self { case .easy: "쉬움"; case .medium: "보통"; case .hard: "어려움" } }
}
struct ComputerOpponent {
    static func gomokuMove(in game: GomokuGame, difficulty: ComputerDifficulty) -> Int? {
        guard game.winner == nil, !game.isDraw else { return nil }
        let board = game.board, me = game.currentPlayer
        if !board.contains(where: { $0 != 0 }) { return 112 }
        let empty = board.indices.filter { board[$0] == 0 }
        func value(_ index: Int, _ player: Int) -> Int {
            var score = 0
            for (dr, dc) in [(1,0),(0,1),(1,1),(1,-1)] {
                var count = 1, open = 0
                for sign in [-1,1] {
                    var r = index/15 + dr*sign, c = index%15 + dc*sign
                    while (0..<15).contains(r), (0..<15).contains(c), board[r*15+c] == player { count += 1; r += dr*sign; c += dc*sign }
                    if (0..<15).contains(r), (0..<15).contains(c), board[r*15+c] == 0 { open += 1 }
                }
                if count >= 5 { return 1_000_000 }
                if open > 0 { score += [0, 2, 15, 180, 8_000][min(count,4)] * (open == 2 ? 4 : 1) }
            }
            return score
        }
        if let win = empty.first(where: { value($0, me) == 1_000_000 }) { return win }
        if let block = empty.first(where: { value($0, 3-me) == 1_000_000 }) { return block }
        let candidates = empty.filter { i in
            for dr in -2...2 { for dc in -2...2 {
                let r = i/15+dr, c = i%15+dc
                if (0..<15).contains(r), (0..<15).contains(c), board[r*15+c] != 0 { return true }
            } }; return false
        }
        let ranked = candidates.sorted { a,b in
            func score(_ i: Int) -> Int {
                let attack = value(i, me), defense = value(i, 3-me)
                return attack * 10 + defense * (difficulty == .hard ? 12 : 8) - abs(i/15-7)-abs(i%15-7)
            }
            let aa = score(a), bb = score(b); return aa == bb ? a < b : aa > bb
        }
        if difficulty == .easy { return Array(ranked.prefix(5)).randomElement() }
        return ranked.first
    }
    struct Move: Equatable, Sendable { let from: Int; let to: Int }
    static func chessMove(in game: ChessGame, difficulty: ComputerDifficulty) -> Move? {
        guard game.drawReason == nil else { return nil }
        let root = game.currentColor
        func moves(_ g: ChessGame) -> [Move] {
            g.board.indices.filter { g.board[$0]?.color == g.currentColor }.flatMap { from in g.legalMoves(from: from).map { Move(from: from, to: $0) } }
        }
        func pieceValue(_ p: ChessPiece?) -> Int {
            guard let p else { return 0 }
            switch p.kind { case .pawn: return 100; case .knight: return 320; case .bishop: return 330; case .rook: return 500; case .queen: return 900; case .king: return 20_000 }
        }
        func evaluate(_ g: ChessGame) -> Int {
            g.board.indices.reduce(0) { sum, i in
                guard let p = g.board[i] else { return sum }
                let center = 14 - abs(2*(i/8)-7) - abs(2*(i%8)-7)
                let advance = p.color == .white ? 6-i/8 : i/8-1
                let positional = p.kind == .pawn ? advance*8 : [.knight,.bishop].contains(p.kind) ? center*3 : 0
                return sum + (pieceValue(p)+positional)*(p.color == root ? 1 : -1)
            }
        }
        let depth = difficulty == .easy ? 1 : difficulty == .medium ? 2 : 3
        let limit = difficulty == .easy ? 100 : difficulty == .medium ? 1_000 : 5_000
        var nodes = 0
        func search(_ g: ChessGame, _ remaining: Int, _ alphaIn: Int, _ betaIn: Int) -> Int {
            nodes += 1
            if Task.isCancelled || nodes >= limit { return evaluate(g) }
            if g.drawReason != nil { return 0 }
            let legal = moves(g)
            if legal.isEmpty { return g.isInCheck ? (g.currentColor == root ? -100_000-remaining : 100_000+remaining) : 0 }
            if remaining == 0 { return evaluate(g) }
            var alpha = alphaIn, beta = betaIn
            let maximizing = g.currentColor == root
            var best = maximizing ? -1_000_000 : 1_000_000
            for move in legal.sorted(by: { pieceValue(g.board[$0.to]) > pieceValue(g.board[$1.to]) }) {
                var next = g; next.move(from: move.from, to: move.to)
                let value = search(next, remaining-1, alpha, beta)
                best = maximizing ? max(best,value) : min(best,value)
                if maximizing { alpha = max(alpha,best) } else { beta = min(beta,best) }
                if beta <= alpha || nodes >= limit || Task.isCancelled { break }
            }
            return best
        }
        let legal = moves(game)
        var best: Move?, bestScore = -1_000_001
        for move in legal.sorted(by: { pieceValue(game.board[$0.to]) > pieceValue(game.board[$1.to]) }) {
            if Task.isCancelled { return nil }
            var next = game; next.move(from: move.from, to: move.to)
            let score = search(next, depth-1, -1_000_000, 1_000_000)
            if score > bestScore { bestScore = score; best = move }
            if nodes >= limit { break }
        }
        return best
    }
}
