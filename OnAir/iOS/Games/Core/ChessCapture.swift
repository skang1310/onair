import Foundation

struct ChessCapture: Equatable, Sendable {
    let square: Int
    let piece: ChessPiece
}
extension ChessGame {
    /// Uses the legal destination, including the displaced victim in en passant.
    func captureTarget(from: Int, to: Int) -> ChessCapture? {
        guard legalMoves(from: from).contains(to), let attacker = board[from] else { return nil }
        if let victim = board[to] { return ChessCapture(square: to, piece: victim) }
        if attacker.kind == .pawn, from % 8 != to % 8 {
            let square = to + (attacker.color == .white ? 8 : -8)
            if board.indices.contains(square), let victim = board[square] { return ChessCapture(square: square, piece: victim) }
        }
        return nil
    }
}
struct ChessMotion: Identifiable, Sendable {
    let id = UUID()
    let from: Int
    let to: Int
    let attacker: ChessPiece
    let capture: ChessCapture?
    var announcement: String {
        guard let capture else { return "기물이 이동했어요" }
        return "\(attacker.color == .white ? "백" : "흑") \(attacker.kind.koreanName)이 \(capture.piece.color == .white ? "백" : "흑") \(capture.piece.kind.koreanName)을 잡았어요"
    }
}
extension ChessKind {
    var koreanName: String { switch self { case .king: "킹"; case .queen: "퀸"; case .rook: "룩"; case .bishop: "비숍"; case .knight: "나이트"; case .pawn: "폰" } }
}
