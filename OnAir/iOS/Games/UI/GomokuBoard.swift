import SwiftUI

struct GomokuBoard: View {
    let game: GomokuGame
    let theme: GomokuTheme
    let showLastMove: Bool
    var onPlay: ((Int) -> Void)? = nil
    var preview: Int? = nil
    var cellIdentifierPrefix = "gomoku.cell"

    private var winningLine: [Int] {
        guard let winner = game.winner, let last = game.lastMove else { return [] }
        let row = last / 15, column = last % 15
        for (dr, dc) in [(1, 0), (0, 1), (1, 1), (1, -1)] {
            var line = [last]
            for sign in [-1, 1] {
                var r = row + dr * sign, c = column + dc * sign
                while (0..<15).contains(r), (0..<15).contains(c), game.board[r * 15 + c] == winner {
                    line.append(r * 15 + c)
                    r += dr * sign; c += dc * sign
                }
            }
            if line.count >= 5 { return line }
        }
        return []
    }

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width
            let inset: CGFloat = 14
            let step = (side - inset * 2) / 14
            ZStack {
                RoundedRectangle(cornerRadius: 27)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.8), theme.line.opacity(0.25), Color.black.opacity(0.34)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(theme.texture)
                    .resizable()
                    .scaledToFill()
                    .frame(width: side - 12, height: side - 12)
                    .clipShape(RoundedRectangle(cornerRadius: 21))
                    .overlay(RoundedRectangle(cornerRadius: 21).stroke(.white.opacity(0.5), lineWidth: 1))
                Canvas { context, _ in
                    for n in 0..<15 {
                        let value = inset + CGFloat(n) * step
                        var path = Path()
                        path.move(to: CGPoint(x: inset, y: value))
                        path.addLine(to: CGPoint(x: side - inset, y: value))
                        path.move(to: CGPoint(x: value, y: inset))
                        path.addLine(to: CGPoint(x: value, y: side - inset))
                        context.stroke(path, with: .color(theme.line.opacity(0.78)), lineWidth: n == 0 || n == 14 ? 1.1 : 0.75)
                    }
                    for row in [3, 7, 11] { for column in [3, 7, 11] {
                        let x = inset + CGFloat(column) * step
                        let y = inset + CGFloat(row) * step
                        context.fill(Path(ellipseIn: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)), with: .color(theme.line.opacity(0.86)))
                    } }
                }
                .allowsHitTesting(false)

                ForEach(0..<225) { index in
                    Button { onPlay?(index) } label: {
                        ZStack {
                            Color.clear
                            if game.board[index] != 0 {
                                RealisticGoStone(player: game.board[index])
                                    .padding(0.6)
                                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                            }
                            if preview == index && game.board[index] == 0 {
                                RealisticGoStone(player:game.currentPlayer).opacity(0.45).padding(0.6)
                                Circle().stroke(theme.accent,lineWidth:2).padding(1)
                            }
                            if showLastMove && game.lastMove == index {
                                Circle()
                                    .stroke(game.board[index] == 1 ? .white : Palette.ink, lineWidth: 1.6)
                                    .frame(width: step * 0.32, height: step * 0.32)
                                    .shadow(color: .black.opacity(0.25), radius: 1)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(onPlay == nil || game.winner != nil || game.isDraw)
                    .frame(width:step,height:step)
                    .position(x: inset + CGFloat(index % 15) * step, y: inset + CGFloat(index / 15) * step)
                    .accessibilityIdentifier("\(cellIdentifierPrefix).\(index / 15).\(index % 15)")
                    .accessibilityLabel("\(index / 15 + 1)행 \(index % 15 + 1)열, \(game.board[index] == 0 ? "빈 자리" : game.board[index] == 1 ? "흑돌" : "백돌")\(showLastMove && game.lastMove == index ? ", 마지막 수" : "")")
                }

                if winningLine.count >= 5 {
                    let sorted = winningLine.sorted { $0 / 15 == $1 / 15 ? $0 % 15 < $1 % 15 : $0 / 15 < $1 / 15 }
                    if let first = sorted.first, let last = sorted.last {
                        Path { path in
                            path.move(to: CGPoint(x: inset + CGFloat(first % 15) * step, y: inset + CGFloat(first / 15) * step))
                            path.addLine(to: CGPoint(x: inset + CGFloat(last % 15) * step, y: inset + CGFloat(last / 15) * step))
                        }
                        .stroke(theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .shadow(color: theme.accent, radius: 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: theme.line.opacity(0.24), radius: 19, x: 0, y: 13)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: game.moveCount)
    }
}
