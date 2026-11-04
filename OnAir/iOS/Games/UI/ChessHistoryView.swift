import SwiftUI
struct ChessHistoryView:View {
    let records:[ChessRecord]
    let current:ChessRecord?
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        NavigationStack {
            List {
                if let current { Section("지금 두는 판") { NavigationLink("진행 중인 대국 · \(current.game.moveCount)수") { ChessReplayView(record:current) } } }
                Section("지난 대국") {
                    if records.isEmpty { Text("대국을 마치거나 새 게임을 시작하면 기록이 남아요.").foregroundStyle(.secondary) }
                    ForEach(records) { record in NavigationLink { ChessReplayView(record:record) } label: {
                        VStack(alignment:.leading,spacing:6) { Text(record.result).font(.headline);Text("\(record.computer ? "컴퓨터 대결" : "가족 2인") · \(record.game.moveCount)수 · \(record.date.formatted(.dateTime.month().day()))").font(.caption).foregroundStyle(.secondary) }
                    } }
                }
            }.scrollContentBackground(.hidden).background(Palette.paper).navigationTitle("체스 대국 기록").toolbar { Button("완료") { dismiss() } }
        }
    }
}
struct ChessReplayView:View {
    let record:ChessRecord
    @State private var step:Int
    init(record:ChessRecord) { self.record=record;_step=State(initialValue:record.game.moveCount) }
    private var position:ChessGame { record.game.position(after:step) }
    var body:some View {
        ScrollView { VStack(spacing:18) {
            Text(record.result).font(.title3.bold())
            ChessArena(game:position,theme:.castle,showLastMove:true,selected:nil,motion:nil,phase:0,locked:true,select:{_ in},flatBoard:true,pending:nil)
            Text("\(step) / \(record.game.moveCount)수").font(.headline.monospacedDigit()).accessibilityIdentifier("chess.replay.step")
            if let last=position.lastMove { Text("\(last.piece.color == .white ? "백" : "흑") \(last.piece.kind.koreanName) · \(coordinate(last.from)) → \(coordinate(last.to))").foregroundStyle(Palette.teal) }
            Slider(value:Binding(get:{Double(step)},set:{step=Int($0.rounded())}),in:0...Double(max(1,record.game.moveCount)),step:1).accessibilityLabel("복기 수순")
            HStack {
                Button { step=0 } label:{Image(systemName:"backward.end.fill").frame(minWidth:44,minHeight:44)}.accessibilityLabel("처음")
                Button { step=max(0,step-1) } label:{Image(systemName:"chevron.left").frame(minWidth:44,minHeight:44)}.disabled(step == 0).accessibilityLabel("이전 수").accessibilityIdentifier("chess.replay.previous")
                Spacer()
                Button { step=min(record.game.moveCount,step+1) } label:{Image(systemName:"chevron.right").frame(minWidth:44,minHeight:44)}.disabled(step == record.game.moveCount).accessibilityLabel("다음 수").accessibilityIdentifier("chess.replay.next")
                Button { step=record.game.moveCount } label:{Image(systemName:"forward.end.fill").frame(minWidth:44,minHeight:44)}.accessibilityLabel("마지막")
            }.buttonStyle(.glass)
            Text("복기 중에는 실제 대국이 바뀌지 않아요.").font(.caption).foregroundStyle(.secondary)
        }.padding(16).frame(maxWidth:760).frame(maxWidth:.infinity) }.background(Palette.paper).navigationTitle("한 수씩 복기").navigationBarTitleDisplayMode(.inline)
    }
    private func coordinate(_ index:Int)->String { "\(Array("abcdefgh")[index%8])\(8-index/8)" }
}
