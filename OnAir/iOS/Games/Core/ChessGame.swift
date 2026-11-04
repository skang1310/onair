import Foundation

enum ChessColor: String, Codable, Sendable { case white, black; var opposite: Self { self == .white ? .black : .white } }
enum ChessKind: String, Codable, Sendable { case pawn, knight, bishop, rook, queen, king }
struct ChessPiece: Equatable, Codable, Sendable { let color: ChessColor; var kind: ChessKind }
struct ChessGame: Codable, Sendable, Equatable {
    private(set) var board: [ChessPiece?]
    private(set) var currentColor: ChessColor = .white
    private var rights = Set([0,7,56,63])
    private var enPassant: Int?
    private var halfmoveClock = 0
    private var history: [Snapshot] = []
    private struct Snapshot: Codable, Sendable, Equatable { let board: [ChessPiece?]; let color: ChessColor; let rights: Set<Int>; let ep: Int?; let halfmove: Int }
    init() {
        board = Array(repeating: nil, count: 64)
        let back: [ChessKind] = [.rook,.knight,.bishop,.queen,.king,.bishop,.knight,.rook]
        for c in 0..<8 { board[c] = ChessPiece(color: .black, kind: back[c]); board[8+c] = ChessPiece(color: .black, kind: .pawn); board[48+c] = ChessPiece(color: .white, kind: .pawn); board[56+c] = ChessPiece(color: .white, kind: back[c]) }
    }
    var validSession: Bool {
        func validBoard(_ board:[ChessPiece?]) -> Bool {
            board.count == 64 && [ChessColor.white,.black].allSatisfy { color in board.filter { $0 == ChessPiece(color:color,kind:.king) }.count == 1 }
        }
        let corners=Set([0,7,56,63])
        return validBoard(board) && rights.isSubset(of:corners) && halfmoveClock >= 0 && halfmoveClock <= 100_000 && history.count <= 5000 &&
            (enPassant.map { (16..<24).contains($0) || (40..<48).contains($0) } ?? true) &&
            history.allSatisfy { validBoard($0.board) && $0.rights.isSubset(of:corners) && $0.halfmove >= 0 && ($0.ep.map { (16..<24).contains($0) || (40..<48).contains($0) } ?? true) }
    }
    var isFinished: Bool { drawReason != nil || !board.indices.contains { board[$0]?.color == currentColor && !legalMoves(from:$0).isEmpty } }
    func position(after ply:Int) -> ChessGame {
        let count=max(0,min(ply,history.count))
        guard count < history.count else { return self }
        let snapshot=history[count]
        var result=self
        result.board=snapshot.board;result.currentColor=snapshot.color;result.rights=snapshot.rights;result.enPassant=snapshot.ep;result.halfmoveClock=snapshot.halfmove
        result.history=Array(history.prefix(count));return result
    }
    var isInCheck: Bool { checked(currentColor) }
    var status: String {
        let hasMoves = board.indices.contains { board[$0]?.color == currentColor && !legalMoves(from: $0).isEmpty }
        if !hasMoves { return isInCheck ? "체크메이트" : "스테일메이트 · 무승부" }
        if let draw = drawReason { return draw }
        return isInCheck ? "체크" : (currentColor == .white ? "백의 차례" : "흑의 차례")
    }
    func legalMoves(from: Int) -> [Int] {
        guard board.indices.contains(from), let p = board[from], p.color == currentColor else { return [] }
        return pseudo(from).filter { to in
            guard board[to]?.kind != .king else { return false }
            var next = self; next.apply(from, to)
            return !next.checked(p.color)
        }
    }
    @discardableResult mutating func move(from: Int, to: Int, promotion: ChessKind = .queen) -> Bool {
        guard drawReason == nil, [.queen, .rook, .bishop, .knight].contains(promotion), legalMoves(from: from).contains(to) else { return false }
        history.append(Snapshot(board: board, color: currentColor, rights: rights, ep: enPassant, halfmove: halfmoveClock))
        apply(from, to, promotion: promotion); currentColor = currentColor.opposite; return true
    }
    struct LastMove: Equatable, Sendable { let from: Int; let to: Int; let piece: ChessPiece }
    var lastMove: LastMove? {
        guard let prior = history.last else { return nil }
        let departed = board.indices.filter { prior.board[$0]?.color == prior.color && board[$0]?.color != prior.color }
        guard let from = departed.first(where: { prior.board[$0]?.kind == .king }) ?? departed.first,
              let piece = prior.board[from] else { return nil }
        let arrived = board.indices.filter { board[$0]?.color == prior.color && board[$0] != prior.board[$0] }
        guard let to = arrived.first(where: { board[$0]?.kind == piece.kind }) ?? arrived.first else { return nil }
        return LastMove(from: from, to: to, piece: piece)
    }
    var moveCount: Int { history.count }
    mutating func undo() { guard let s = history.popLast() else { return }; board = s.board; currentColor = s.color; rights = s.rights; enPassant = s.ep; halfmoveClock = s.halfmove }
    mutating func reset() { self = ChessGame() }
    // Casual play automatically accepts the usual threefold/50-move claims.
    var drawReason: String? {
        if halfmoveClock >= 100 { return "50수 규칙 · 무승부" }
        let nonKings = board.indices.filter { board[$0] != nil && board[$0]?.kind != .king }
        if nonKings.isEmpty || (nonKings.count == 1 && [.bishop,.knight].contains(board[nonKings[0]]!.kind)) { return "기물 부족 · 무승부" }
        if !nonKings.isEmpty, nonKings.allSatisfy({ board[$0]?.kind == .bishop }), Set(nonKings.map { ($0/8+$0%8)%2 }).count == 1 { return "기물 부족 · 무승부" }
        let key = positionKey()
        var matches = 1
        for snap in history {
            var prior = self; prior.board = snap.board; prior.currentColor = snap.color; prior.rights = snap.rights; prior.enPassant = snap.ep
            if prior.positionKey() == key { matches += 1 }
        }
        return matches >= 3 ? "동일 위치 3회 · 무승부" : nil
    }
    private func positionKey() -> String {
        var validEP: Int?
        if let ep = enPassant {
            for from in board.indices where board[from] == ChessPiece(color: currentColor, kind: .pawn) {
                if pseudo(from).contains(ep) {
                    var next = self; next.apply(from, ep)
                    if !next.checked(currentColor) { validEP = ep; break }
                }
            }
        }
        return board.map { $0.map { "\($0.color.rawValue):\($0.kind.rawValue)" } ?? "-" }.joined(separator: ",") + currentColor.rawValue + rights.sorted().description + (validEP.map(String.init) ?? "-")
    }
    private func checked(_ color: ChessColor) -> Bool {
        guard let k = board.firstIndex(where: { $0 == ChessPiece(color: color, kind: .king) }) else { return true }
        return attacked(k, by: color.opposite)
    }
    private func attacked(_ square: Int, by color: ChessColor) -> Bool {
        board.indices.contains { i in
            guard let p = board[i], p.color == color else { return false }
            return pseudo(i, attacksOnly: true).contains(square)
        }
    }
    private func pseudo(_ from: Int, attacksOnly: Bool = false) -> [Int] {
        guard let p = board[from] else { return [] }
        let r = from/8, c = from%8
        var moves: [Int] = []
        func add(_ rr: Int, _ cc: Int) {
            guard (0..<8).contains(rr), (0..<8).contains(cc) else { return }
            let t = rr*8+cc
            if attacksOnly || board[t]?.color != p.color { moves.append(t) }
        }
        switch p.kind {
        case .pawn:
            let d = p.color == .white ? -1 : 1
            for dc in [-1,1] {
                let rr = r+d, cc = c+dc
                if (0..<8).contains(rr), (0..<8).contains(cc) {
                    let t = rr*8+cc
                    if attacksOnly || (board[t] != nil && board[t]?.color != p.color) || t == enPassant { moves.append(t) }
                }
            }
            if !attacksOnly, (0..<8).contains(r+d), board[(r+d)*8+c] == nil {
                moves.append((r+d)*8+c)
                if r == (p.color == .white ? 6 : 1), board[(r+2*d)*8+c] == nil { moves.append((r+2*d)*8+c) }
            }
        case .knight:
            for (dr,dc) in [(2,1),(2,-1),(-2,1),(-2,-1),(1,2),(1,-2),(-1,2),(-1,-2)] { add(r+dr,c+dc) }
        case .king:
            for dr in -1...1 { for dc in -1...1 where dr != 0 || dc != 0 { add(r+dr,c+dc) } }
            if !attacksOnly, from == (p.color == .white ? 60 : 4), !checked(p.color) {
                for rook in [r*8,r*8+7] where rights.contains(rook) && board[rook] == ChessPiece(color: p.color, kind: .rook) {
                    let dir = rook%8 == 0 ? -1 : 1
                    let between = dir == 1 ? [from+1,from+2] : [from-1,from-2,from-3]
                    if between.allSatisfy({ board[$0] == nil }), !attacked(from+dir, by: p.color.opposite), !attacked(from+2*dir, by: p.color.opposite) { moves.append(from+2*dir) }
                }
            }
        case .bishop,.rook,.queen:
            let diagonal = [(1,1),(1,-1),(-1,1),(-1,-1)]
            let straight = [(1,0),(-1,0),(0,1),(0,-1)]
            let dirs = p.kind == .bishop ? diagonal : p.kind == .rook ? straight : diagonal+straight
            for (dr,dc) in dirs {
                var rr = r+dr, cc = c+dc
                while (0..<8).contains(rr), (0..<8).contains(cc) {
                    let t = rr*8+cc
                    if attacksOnly || board[t]?.color != p.color { moves.append(t) }
                    if board[t] != nil { break }; rr += dr; cc += dc
                }
            }
        }
        return moves
    }
    private mutating func apply(_ from: Int, _ to: Int, promotion: ChessKind = .queen) {
        guard var p = board[from] else { return }
        halfmoveClock = p.kind == .pawn || board[to] != nil ? 0 : halfmoveClock+1
        if p.kind == .pawn, to == enPassant, board[to] == nil { board[to + (p.color == .white ? 8 : -8)] = nil }
        if p.kind == .king {
            rights.remove(p.color == .white ? 56 : 0); rights.remove(p.color == .white ? 63 : 7)
            if abs(to-from) == 2 {
                let rook = to > from ? from+3 : from-4, dest = to > from ? from+1 : from-1
                board[dest] = board[rook]; board[rook] = nil
            }
        }
        rights.remove(from); rights.remove(to)
        enPassant = p.kind == .pawn && abs(to-from) == 16 ? (from+to)/2 : nil
        if p.kind == .pawn && (to/8 == 0 || to/8 == 7) { p.kind = promotion }
        board[to] = p; board[from] = nil
    }
}
