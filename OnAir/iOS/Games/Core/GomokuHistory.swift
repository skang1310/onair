import Foundation

struct GomokuRecord: Codable, Identifiable, Equatable {
    let id: String
    let playedAt: Date
    let moves: [Int]
    let winner: Int?
    let isDraw: Bool
    let computer: Bool
    let theme: String

    var result: String {
        if let winner { return winner == 1 ? "흑돌 승리" : "백돌 승리" }
        return isDraw ? "무승부" : "중단된 대국"
    }

    var opponent: String { computer ? "컴퓨터 대결" : "가족 2인" }

    func position(after count: Int) -> GomokuGame {
        var game = GomokuGame()
        for index in moves.prefix(max(0, min(count, moves.count))) {
            game.play(row: index / 15, column: index % 15)
        }
        return game
    }
}

enum GomokuHistory {
    static let key = "history.gomoku"

    static func load(from defaults: UserDefaults = .standard) -> [GomokuRecord] {
        guard let data = defaults.data(forKey: key),
              let records = try? JSONDecoder().decode([GomokuRecord].self, from: data) else { return [] }
        return Array(records.filter { record in
            record.moves.count <= 225 && Set(record.moves).count == record.moves.count && record.moves.allSatisfy { (0..<225).contains($0) } && (record.winner == nil || record.winner == 1 || record.winner == 2)
        }.prefix(30))
    }

    static func save(_ records: [GomokuRecord], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }

    static func upsert(_ record: GomokuRecord, in records: [GomokuRecord]) -> [GomokuRecord] {
        Array(([record] + records.filter { $0.id != record.id }).prefix(30))
    }
}
