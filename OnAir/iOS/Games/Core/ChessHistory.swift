import Foundation
struct ChessRecord:Codable,Identifiable {
    let id:String
    let date:Date
    let game:ChessGame
    let computer:Bool
    var result:String { game.isFinished ? game.status == "체크메이트" ? (game.currentColor == .white ? "흑 승리 · 체크메이트" : "백 승리 · 체크메이트") : game.status : "중단된 대국" }
}
enum ChessHistory {
    static let key="history.chess.v1"
    static func load()->[ChessRecord] {
        guard let data=UserDefaults.standard.data(forKey:key),let records=try? JSONDecoder().decode([ChessRecord].self,from:data) else { return [] }
        return Array(records.filter { $0.game.validSession }.prefix(10))
    }
    static func save(_ records:[ChessRecord]) { if let data=try? JSONEncoder().encode(Array(records.prefix(10))) { UserDefaults.standard.set(data,forKey:key) } }
    static func upsert(_ record:ChessRecord,in records:[ChessRecord])->[ChessRecord] { Array(([record]+records.filter{$0.id != record.id}).prefix(10)) }
}
