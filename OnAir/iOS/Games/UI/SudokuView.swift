import SwiftUI

struct SudokuView: View {
    @State private var game = restoreGame(SudokuGame.self, key: "saved.sudoku", fallback: SudokuGame())
    @State private var selected: Int?
    @State private var noteMode = false
    @State private var pendingDifficulty: SudokuDifficulty?
    @State private var difficulty = restoreGame(SudokuGame.self, key: "saved.sudoku", fallback: SudokuGame()).difficulty
    var body: some View {
        GameScaffold(title: "스도쿠", subtitle: "A MOMENT TO THINK", rules: "각 가로줄, 세로줄, 3×3 상자에 1부터 9까지 한 번씩 채워 주세요.\n\n빈 칸을 고른 뒤 숫자를 누르세요. 메모 모드에서는 후보 숫자를 적을 수 있어요. 빨간 숫자는 정답과 다른 숫자입니다. 힌트는 한 칸을 완성해 줍니다. 난이도를 바꾸면 새로운 퍼즐이 시작됩니다.", restart: { game = SudokuGame(difficulty: difficulty); selected = nil }, undo: nil) {
            StatusPill(text: game.isComplete ? "완성! 오늘의 퍼즐을 해결했어요." : "\(game.board.filter { $0 != 0 }.count) / 81 칸 · 한 칸씩 차근차근", color: Palette.teal)
            Picker("난이도", selection: Binding(get: { difficulty }, set: { pendingDifficulty = $0 })) { ForEach(SudokuDifficulty.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            GeometryReader { geo in
                let side = geo.size.width / 9
                ZStack {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 9), spacing: 0) {
                        ForEach(0..<81) { index in
                            Button { selected = index } label: {
                                ZStack {
                                    (selected == index ? Palette.indigo.opacity(0.2) : selected.map { $0 / 9 == index / 9 || $0 % 9 == index % 9 } == true ? Palette.indigo.opacity(0.06) : Color.white.opacity(0.8))
                                    if game.board[index] != 0 { Text("\(game.board[index])").font(.system(size: side * 0.49, weight: game.puzzle[index] != 0 ? .semibold : .regular, design: .rounded)).foregroundStyle(game.mistakes.contains(index) ? Color.red : game.puzzle[index] != 0 ? Palette.ink : Palette.indigo) }
                                    else { LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3), spacing: 0) { ForEach(1...9, id: \.self) { number in Text(game.notes[index].contains(number) ? String(number) : " ").font(.system(size: side * 0.22)).foregroundStyle(Palette.teal) } }.padding(3) }
                                }.frame(height: side).overlay(Rectangle().stroke(Palette.ink.opacity(0.1), lineWidth: 0.5))
                            }.buttonStyle(.plain).accessibilityLabel("\(index/9+1)행 \(index%9+1)열, \(game.board[index] == 0 ? "빈 칸" : String(game.board[index]))").accessibilityIdentifier("sudoku.cell.\(index/9).\(index%9)")
                        }
                    }
                    Canvas { context, size in for i in 0...3 { var path = Path(); let n = CGFloat(i)*size.width/3; path.move(to: CGPoint(x:n,y:0)); path.addLine(to: CGPoint(x:n,y:size.height)); path.move(to: CGPoint(x:0,y:n)); path.addLine(to: CGPoint(x:size.width,y:n)); context.stroke(path, with:.color(Palette.ink.opacity(0.6)), lineWidth: 1.8) } }.allowsHitTesting(false)
                }.clipShape(RoundedRectangle(cornerRadius: 12))
            }.aspectRatio(1, contentMode: .fit)
            HStack(spacing: 6) { ForEach(1...9, id: \.self) { number in Button { if let selected { if noteMode { game.toggleNote(number, at: selected) } else { game.set(number, at: selected) } } } label: { Text("\(number)").font(.title3.weight(.semibold)).frame(maxWidth: .infinity).frame(minHeight: 44) }.buttonStyle(.glass).disabled(selected == nil || game.isComplete).accessibilityIdentifier("sudoku.number.\(number)") } }
            HStack {
                Button { noteMode.toggle() } label: { Label("메모", systemImage: noteMode ? "pencil.circle.fill" : "pencil") }.buttonStyle(.glass).tint(noteMode ? Palette.teal : Palette.indigo).accessibilityIdentifier("sudoku.notes")
                Button { if let selected { game.set(0, at: selected) } } label: { Label("지우기", systemImage: "eraser") }.buttonStyle(.glass).disabled(selected == nil).accessibilityIdentifier("sudoku.erase")
                Button { selected = game.hint() } label: { Label("힌트", systemImage: "lightbulb") }.buttonStyle(.glass).disabled(game.isComplete).accessibilityIdentifier("sudoku.hint")
            }
        }.confirmationDialog("난이도를 바꾸고 새로운 퍼즐을 시작할까요?", isPresented: Binding(get: { pendingDifficulty != nil }, set: { if !$0 { pendingDifficulty = nil } }), titleVisibility: .visible) {
            Button("새 퍼즐 시작", role: .destructive) { if let next = pendingDifficulty { difficulty = next; game = SudokuGame(difficulty: next); selected = nil }; pendingDifficulty = nil }
            Button("취소", role: .cancel) { pendingDifficulty = nil }
        }.navigationBarTitleDisplayMode(.inline).onChange(of: try? JSONEncoder().encode(game)) { _, _ in saveGame(game, key: "saved.sudoku") }.onDisappear { saveGame(game, key: "saved.sudoku") }.onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in saveGame(game, key: "saved.sudoku") }
    }
}
