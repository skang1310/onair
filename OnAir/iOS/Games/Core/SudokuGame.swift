import Foundation

enum SudokuDifficulty: String, CaseIterable, Codable { case easy = "쉬움", medium = "보통", hard = "어려움" }
struct SudokuGame: Codable {
    let difficulty: SudokuDifficulty
    private(set) var puzzle: [Int]
    private(set) var board: [Int]
    let solution: [Int]
    private(set) var notes = Array(repeating: Set<Int>(), count: 81)
    var isComplete: Bool { board == solution }
    var mistakes: Set<Int> { Set(board.indices.filter { board[$0] != 0 && board[$0] != solution[$0] }) }
    init(difficulty: SudokuDifficulty = .easy) {
        self.difficulty = difficulty
        // This seed has exactly one solution. Digit permutations preserve uniqueness.
        let seed = "530070000600195000098000060800060003400803001700020006060000280000419005000080079".map { Int(String($0))! }
        let solved = "534678912672195348198342567859761423426853791713924856961537284287419635345286179".map { Int(String($0))! }
        let digits = Array(1...9).shuffled()
        let rows = (0..<3).shuffled().flatMap { band in (0..<3).shuffled().map { band*3+$0 } }
        let cols = (0..<3).shuffled().flatMap { stack in (0..<3).shuffled().map { stack*3+$0 } }
        let transpose = Bool.random()
        let positions = (0..<81).map { i in transpose ? rows[i%9]*9+cols[i/9] : rows[i/9]*9+cols[i%9] }
        solution = positions.map { digits[solved[$0]-1] }
        var clues = positions.map { seed[$0] == 0 ? 0 : digits[seed[$0]-1] }
        let extra = difficulty == .easy ? 15 : difficulty == .medium ? 7 : 0
        for i in clues.indices.filter({ clues[$0] == 0 }).shuffled().prefix(extra) { clues[i] = solution[i] }
        puzzle = clues; board = clues
    }
    mutating func set(_ value: Int, at index: Int) {
        guard (0..<81).contains(index), (0...9).contains(value), puzzle[index] == 0 else { return }
        board[index] = value; notes[index].removeAll()
    }
    mutating func toggleNote(_ value: Int, at index: Int) {
        guard (0..<81).contains(index), (1...9).contains(value), puzzle[index] == 0, board[index] == 0 else { return }
        if notes[index].contains(value) { notes[index].remove(value) } else { notes[index].insert(value) }
    }
    @discardableResult mutating func hint() -> Int? {
        guard let i = board.indices.first(where: { board[$0] != solution[$0] }) else { return nil }
        board[i] = solution[i]; notes[i].removeAll(); return i
    }
    mutating func reset() { board = puzzle; notes = Array(repeating: Set<Int>(), count: 81) }
}
