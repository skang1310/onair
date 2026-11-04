import Foundation
protocol SavedGameValidation { var validSession: Bool { get } }
extension GomokuGame: SavedGameValidation {}
extension ChessGame: SavedGameValidation {}
