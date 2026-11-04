import SwiftUI

struct GomokuView: View {
    let saveKey: String
    let playerNames: [String]?
    let onFinish: ((Int?) -> Void)?
    @State private var game = restoreGame(GomokuGame.self, key: "saved.gomoku", fallback: GomokuGame())
    @State private var computer = UserDefaults.standard.bool(forKey: "gomoku.computer")
    @State private var difficulty = UserDefaults.standard.string(forKey: "gomoku.difficulty") ?? "medium"
    @State private var records = GomokuHistory.load()
    @State private var sessionID = UserDefaults.standard.string(forKey: "gomoku.sessionID") ?? UUID().uuidString
    @State private var showHistory = false
    @State private var showBoardMenu = false
    @AppStorage("gomoku.showLastMove") private var showLastMove = true
    @AppStorage("gomoku.theme") private var themeID = "wood"
    @State private var placement = 0
    @Environment(\.scenePhase) private var scenePhase

    init(saveKey: String = "saved.gomoku", playerNames: [String]? = nil, onFinish: ((Int?) -> Void)? = nil) {
        self.saveKey = saveKey; self.playerNames = playerNames; self.onFinish = onFinish
        _game = State(initialValue: restoreGame(GomokuGame.self, key: saveKey, fallback: GomokuGame()))
        _computer = State(initialValue: playerNames == nil ? UserDefaults.standard.bool(forKey: "gomoku.computer") : false)
        if playerNames != nil { _sessionID = State(initialValue: saveKey); _records = State(initialValue: []) }
    }

    private var theme: GomokuTheme { GomokuTheme(rawValue: themeID) ?? .wood }
    private var computerTurn: Bool { computer && game.currentPlayer == 2 && game.winner == nil && !game.isDraw }
    private var taskID: String { "\(game.moveCount)-\(computer)-\(difficulty)-\(scenePhase == .active)-\(showHistory)-\(showBoardMenu)" }
    private var currentRecord: GomokuRecord? {
        guard game.moveCount > 0, game.winner == nil, !game.isDraw else { return nil }
        return makeRecord()
    }

    var body: some View {
        GameScaffold(
            title: "오목", subtitle: "FIVE IN A ROW",
            rules: "흑돌부터 번갈아 빈 교차점에 돌을 놓으세요. 가로, 세로, 대각선으로 다섯 개 이상 이어지면 승리합니다.\n\n이 게임은 자유 오목입니다. 금수 규칙은 없어요. 가족과 번갈아 두거나 컴퓨터와 대결할 수 있어요. 컴퓨터 대결에서는 내가 흑돌로 먼저 둡니다.",
            restart: { beginNewGame() }, undo: { undoTurn() }, compactBoard:true
        ) {
            HStack(spacing: 10) {
                playerCard(1)
                playerCard(2)
            }
            .accessibilityIdentifier("gomoku.turnCards")

            GomokuBoard(game: game, theme: theme, showLastMove: showLastMove,onPlay:{ index in
                guard !computerTurn, !showBoardMenu else { return }
                guard scenePhase == .active,game.board[index] == 0 else { return }
                play(index)
            })
            .contentShape(Rectangle())
            .highPriorityGesture(LongPressGesture(minimumDuration:0.5,maximumDistance:14).onEnded { _ in openBoardMenu() })

            HStack(spacing: 12) {
                Image(systemName: game.winner != nil ? "sparkles" : computerTurn ? "brain.head.profile" : "hand.point.up.left.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle).font(.subheadline.bold())
                    Text(statusDetail).font(.caption).opacity(0.75)
                }
                Spacer()
                Text("\(game.moveCount)수").font(.caption.bold()).monospacedDigit()
            }
            .foregroundStyle(Palette.ink)
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
            .accessibilityIdentifier("gomoku.status")

            if game.winner != nil || game.isDraw {
                HStack {
                    Button("승부 복기") { showHistory=true }.buttonStyle(.glass).accessibilityIdentifier("gomoku.reviewResult")
                    Button("새 대국 시작") { beginNewGame() }.buttonStyle(.glassProminent).accessibilityIdentifier("gomoku.playAgain")
                }.frame(maxWidth:.infinity)
            } else if showLastMove, let last=game.lastMove {
                Text("직전 수 · \(last/15+1)행 \(last%15+1)열").font(.caption).foregroundStyle(Palette.teal).accessibilityIdentifier("gomoku.lastCoordinate")
            }
            Button { showHistory = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath").font(.title3)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("대국 기록 · 복기").font(.subheadline.bold())
                        Text(records.isEmpty ? "이 판부터 수순이 기록돼요" : "지난 \(records.count)판을 한 수씩 다시 보기")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
                }
                .foregroundStyle(Palette.ink)
                .padding(16)
                .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(Palette.line, lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("gomoku.history")


        }
        .toolbar { ToolbarItem(placement:.topBarTrailing) { Button(action:openBoardMenu) { Image(systemName:"ellipsis") }.accessibilityLabel("보드 메뉴").accessibilityIdentifier("gomoku.boardMenu") } }
        .sheet(isPresented:$showBoardMenu) {
            BoardQuickMenu(title:"오목",showLastMove:$showLastMove,canUndo:game.moveCount>0,undo:undoTurn,restart:beginNewGame) {
                BoardThemePicker(title:"오목의 풍경",entries:GomokuTheme.allCases.map { ($0.rawValue,$0.title,$0.line) },selection:$themeID)
            } settings: {
                if playerNames == nil { OpponentSettings(computer:computer,difficulty:difficulty,start:{ setOpponent($0,$1); showBoardMenu=false }) }
                else { Label("게임 밤은 두 사람이 번갈아 둡니다",systemImage:"person.2").font(.subheadline) }
                Text("자유 오목 · 금수 없이 다섯 돌을 이으면 승리").font(.caption).foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showHistory) { GomokuHistoryView(records: $records, current: currentRecord) }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.65), trigger: placement,condition:{_,_ in UserDefaults.standard.object(forKey:"arcade.haptics") as? Bool ?? true})
        .task(id: taskID) { await playComputer() }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if playerNames == nil { UserDefaults.standard.set(sessionID, forKey: "gomoku.sessionID") }; if let winner = game.winner { onFinish?(winner-1) } else if game.isDraw { onFinish?(nil) } }
        .onChange(of: game) { _, _ in saveGame(game, key: saveKey) }
        .onChange(of: game.winner) { _, value in if let value { onFinish?(value-1) } }
        .onChange(of: game.isDraw) { _, value in if value { onFinish?(nil) } }
        .onDisappear { saveGame(game, key: saveKey) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in saveGame(game, key: saveKey) }
    }

    private func openBoardMenu() { showBoardMenu = true; if UserDefaults.standard.object(forKey:"arcade.haptics") as? Bool ?? true { UIImpactFeedbackGenerator(style:.soft).impactOccurred() } }

    private func playerCard(_ player: Int) -> some View {
        let active = game.winner == player || (game.winner == nil && !game.isDraw && game.currentPlayer == player)
        return HStack(spacing: 9) {
            RealisticGoStone(player: player).frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(playerNames?[player-1] ?? (player == 1 ? "흑돌" : "백돌")).font(.subheadline.bold())
                Text(computer && player == 2 ? "컴퓨터" : player == 1 ? "선공" : "후공")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if active { Circle().fill(theme.accent).frame(width: 6, height: 6) }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(active ? Color.white.opacity(0.9) : Color.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(active ? Palette.teal : Palette.line, lineWidth: active ? 1.3 : 0.8))
    }

    private var statusTitle: String {
        if let winner = game.winner { return winner == 1 ? "흑돌의 승리" : "백돌의 승리" }
        if game.isDraw { return "무승부" }
        if computerTurn { return "컴퓨터가 생각 중이에요" }
        if let playerNames { return "\(playerNames[game.currentPlayer-1]) 차례" }
        return game.currentPlayer == 1 ? "흑돌 차례" : "백돌 차례"
    }

    private var statusDetail: String {
        if game.winner != nil { return "다섯 돌이 이어졌어요 · 복기에서 다시 보세요" }
        if game.isDraw { return "판을 모두 채웠어요" }
        if computerTurn { return "잠시만 기다려 주세요" }
        return "교차점을 탭해 돌을 놓으세요"
    }

    private func makeRecord() -> GomokuRecord {
        GomokuRecord(id: sessionID, playedAt: Date(), moves: game.moves, winner: game.winner, isDraw: game.isDraw, computer: computer, theme: themeID)
    }

    private func archiveCurrentIfNeeded() {
        guard playerNames == nil, game.moveCount > 0 else { return }
        records = GomokuHistory.upsert(makeRecord(), in: records)
        GomokuHistory.save(records)
    }

    private func beginNewGame() {
        if game.winner == nil && !game.isDraw { archiveCurrentIfNeeded() }
        game.reset()
        sessionID = UUID().uuidString
        if playerNames == nil { UserDefaults.standard.set(sessionID, forKey: "gomoku.sessionID") }
    }

    private func setOpponent(_ useComputer: Bool, _ level: String) {
        beginNewGame()
        computer = useComputer
        difficulty = level
        UserDefaults.standard.set(useComputer, forKey: "gomoku.computer")
        UserDefaults.standard.set(level, forKey: "gomoku.difficulty")
    }

    private func play(_ index: Int) {
        let count = game.moveCount
        game.play(row: index / 15, column: index % 15)
        guard game.moveCount != count else { return }
        placement += 1
        if game.winner != nil || game.isDraw { archiveCurrentIfNeeded() }
    }

    private func undoTurn() {
        guard game.moveCount > 0 else { return }
        if playerNames == nil && (game.winner != nil || game.isDraw) {
            records.removeAll { $0.id == sessionID }
            GomokuHistory.save(records)
        }
        let count = game.moveCount
        game.undo()
        if computer && count.isMultiple(of: 2) { game.undo() }
    }

    private func playComputer() async {
        guard !showHistory, !showBoardMenu, computerTurn, scenePhase == .active else { return }
        do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
        let snapshot = game
        let level = ComputerDifficulty(rawValue: difficulty) ?? .medium
        let worker = Task.detached(priority: .userInitiated) { ComputerOpponent.gomokuMove(in: snapshot, difficulty: level) }
        let move = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
        guard !Task.isCancelled, !showHistory, !showBoardMenu, computerTurn, scenePhase == .active, game.board == snapshot.board, let move else { return }
        play(move)
    }
}
