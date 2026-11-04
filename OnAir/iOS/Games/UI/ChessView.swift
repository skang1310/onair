import SwiftUI

struct ChessView: View {
    @State private var game = restoreGame(ChessGame.self, key:"saved.chess",fallback:ChessGame())
    @State private var showBoardMenu = false
    @State private var showHistory=false
    @State private var records=ChessHistory.load()
    @State private var sessionID=UserDefaults.standard.string(forKey:"chess.sessionID") ?? UUID().uuidString
    @State private var selected: Int?
    @State private var inspected:Int?
    @State private var pendingMove:[Int]?
    @AppStorage("chess.confirmMoves") private var confirmMoves = true
    @AppStorage("chess.classicPieces") private var classicPieces = true
    @AppStorage("chess.flatBoard") private var flatBoard = true
    @State private var promotionMove: [Int]?
    @State private var computer = UserDefaults.standard.bool(forKey:"chess.computer")
    @State private var difficulty = UserDefaults.standard.string(forKey:"chess.difficulty") ?? "medium"
    @AppStorage("chess.showLastMove") private var showLastMove = true
    @AppStorage("chess.theme") private var themeID = "castle"
    @AppStorage("chess.battleEffects") private var battleEffects = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var motion: ChessMotion?
    @State private var phase = 0.0
    @State private var animationTask: Task<Void,Never>?
    @State private var captureText: String?
    @State private var impact = 0
    private var theme: ChessTheme { ChessTheme(rawValue:themeID) ?? .castle }
    private var computerTurn: Bool { computer && game.currentColor == .black && !game.isFinished }
    private var taskID: String { "\(game.moveCount)-\(computer)-\(difficulty)-\(scenePhase == .active)-\(motion != nil)-\(showBoardMenu)-\(showHistory)" }
    var body: some View {
        GameScaffold(title:"마법 체스",subtitle:"A LITTLE MAGIC IN EVERY MOVE",rules:"백이 먼저 시작합니다. 내 기물을 누르면 이동 가능한 칸이 보여요. 상대 왕이 공격을 피할 수 없으면 체크메이트입니다.\n\n기물을 잡으면 기사단이 공격하고 상대 석상이 마법 파편으로 사라져요. 테마와 전투 효과를 바꿔도 체스 규칙은 같아요. 동작 줄이기가 켜져 있으면 즉시 이동합니다.\n\n캐슬링, 앙파상, 폰 승격을 지원해요. 스테일메이트, 기물 부족, 3회 반복과 50수 무승부를 자동 판정합니다.",restart:restartGame,undo:{ undoTurn() },compactBoard:true) {
            HStack(spacing:10) { playerCard(.white);playerCard(.black) }
            ChessArena(game:game,theme:theme,showLastMove:showLastMove,selected:selected,motion:motion,phase:phase,locked:motion != nil || computerTurn || game.isFinished,select:selectSquare,flatBoard:flatBoard,pending:pendingMove?.last)
                .contentShape(Rectangle())
                .highPriorityGesture(LongPressGesture(minimumDuration:0.5,maximumDistance:14).onEnded { _ in openBoardMenu() })
            if let infoSquare=selected ?? inspected,let piece=game.board[infoSquare] { pieceExplanation(piece) }
            HStack(spacing:11) {
                Image(systemName:game.isInCheck ? "exclamationmark.shield.fill" : motion != nil ? "sparkles" : "hand.point.up.left.fill").font(.title3)
                VStack(alignment:.leading,spacing:3) {
                    Text(status).font(.subheadline.bold())
                    Text(pendingMove != nil ? "목적지를 확인하고 아래에서 확정하세요" : selected == nil ? "기물을 탭하면 갈 수 있는 칸이 빛나요" : safeInput ? "빛나는 칸을 눌러 목적지를 선택하세요" : "빛나는 칸을 눌러 이동하세요").font(.caption).opacity(0.73)
                }
                Spacer()
                Text("\(game.moveCount)수").font(.caption.bold()).monospacedDigit()
            }.foregroundStyle(game.isInCheck ? .red : Palette.ink).padding(.vertical,12)
                .overlay(alignment:.top) { Rectangle().fill(Palette.line).frame(height:1) }
                .overlay(alignment:.bottom) { Rectangle().fill(Palette.line).frame(height:1) }
                .accessibilityIdentifier("chess.status")
            if game.isFinished {
                VStack(spacing:10) {
                    Label(game.status == "체크메이트" ? (game.currentColor == .white ? "흑의 승리 · 체크메이트" : "백의 승리 · 체크메이트") : game.status,systemImage:"trophy.fill").font(.headline).accessibilityIdentifier("chess.result")
                    Button("새 대국 시작") { restartGame() }.buttonStyle(.glassProminent).accessibilityIdentifier("chess.playAgain")
                }.padding(16).frame(maxWidth:.infinity).glassEffect(.regular,in:RoundedRectangle(cornerRadius:20))
            }
            Button { cancelMotion();pendingMove=nil;selected=nil;showHistory=true } label: { Label("대국 기록 · 복기",systemImage:"clock.arrow.circlepath").frame(maxWidth:.infinity,minHeight:44) }.buttonStyle(.glass).accessibilityIdentifier("chess.history")
            if showLastMove, let captureText { Label(captureText,systemImage:"sparkles").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.teal).accessibilityIdentifier("chess.captureAnnouncement") }
            if showLastMove, let last=game.lastMove {
                Label("직전 수 · \(last.piece.color == .white ? "백" : "흑") \(last.piece.kind.koreanName) \(coordinate(last.from)) → \(coordinate(last.to))",systemImage:"arrow.right").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.teal).accessibilityIdentifier("chess.lastMove")
            }

        }.safeAreaInset(edge:.bottom) { if let pendingMove { moveConfirmation(pendingMove).padding(8) } }.task(id:taskID) { await playComputer() }
        .toolbar { ToolbarItem(placement:.topBarTrailing) { Button(action:openBoardMenu) { Image(systemName:"ellipsis") }.accessibilityLabel("보드 메뉴").accessibilityIdentifier("chess.boardMenu") } }
        .sheet(isPresented:$showBoardMenu) {
            BoardQuickMenu(title:"체스",showLastMove:$showLastMove,canUndo:game.moveCount>0 && motion == nil,undo:undoTurn,restart:restartGame) {
                BoardThemePicker(title:"체스의 풍경",entries:ChessTheme.allCases.map { ($0.rawValue,$0.title,$0.dark) },selection:$themeID)
                Text(theme.caption).font(.caption).foregroundStyle(.secondary)
            } settings: {
                OpponentSettings(computer:computer,difficulty:difficulty,start:{ setOpponent($0,$1); showBoardMenu=false })
                Toggle("클래식 2D 기물",isOn:$classicPieces).accessibilityIdentifier("chess.classicPieces")
                Toggle("착수 전 확인",isOn:$confirmMoves).accessibilityIdentifier("chess.confirmMoves")
                Toggle("정면 보드 · 넓은 터치",isOn:$flatBoard).accessibilityIdentifier("chess.flatBoard")
                Toggle("전투 효과",isOn:$battleEffects).accessibilityIdentifier("chess.effects")
            }
        }
        .sheet(isPresented:$showHistory) { ChessHistoryView(records:records,current:game.moveCount > 0 && !game.isFinished ? ChessRecord(id:sessionID,date:Date(),game:game,computer:computer) : nil) }
        .confirmationDialog("폰을 어떤 기물로 승격할까요?",isPresented:Binding(get:{ promotionMove != nil },set:{ if !$0 { promotionMove=nil } }),titleVisibility:.visible) {
            ForEach([ChessKind.queen,.rook,.bishop,.knight],id:\.rawValue) { kind in Button(kind.koreanName) { if let move=promotionMove { performMove(from:move[0],to:move[1],promotion:kind) };promotionMove=nil } }
            Button("취소",role:.cancel) { promotionMove=nil }
        }.navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight:.heavy,intensity:0.85),trigger:impact,condition:{_,_ in UserDefaults.standard.object(forKey:"arcade.haptics") as? Bool ?? true})
        .onAppear { UserDefaults.standard.set(sessionID,forKey:"chess.sessionID");if game.isFinished { archiveCurrent() } }
        .onChange(of:game) { _,_ in saveGame(game,key:"saved.chess");if game.isFinished { archiveCurrent() } }
        .onChange(of:scenePhase) { _,value in if value != .active { pendingMove=nil;selected=nil;inspected=nil;promotionMove=nil;cancelMotion();saveGame(game,key:"saved.chess") } }
        .onChange(of:themeID) { _,_ in cancelMotion() }
        .onChange(of:confirmMoves) { _,_ in pendingMove=nil }
        .onChange(of:classicPieces) { _,_ in cancelMotion() }
        .onChange(of:flatBoard) { _,_ in pendingMove=nil;selected=nil }
        .onDisappear { pendingMove=nil;selected=nil;inspected=nil;promotionMove=nil;cancelMotion();saveGame(game,key:"saved.chess") }
        .onReceive(NotificationCenter.default.publisher(for:UIApplication.willResignActiveNotification)) { _ in cancelMotion();saveGame(game,key:"saved.chess") }
    }
    private func openBoardMenu() {
        pendingMove=nil;selected=nil;inspected=nil;promotionMove=nil;cancelMotion()
        showBoardMenu=true;if UserDefaults.standard.object(forKey:"arcade.haptics") as? Bool ?? true { UIImpactFeedbackGenerator(style:.soft).impactOccurred() }
    }
    private func archiveCurrent() {
        guard game.moveCount > 0 else { return }
        records=ChessHistory.upsert(ChessRecord(id:sessionID,date:Date(),game:game,computer:computer),in:records);ChessHistory.save(records)
    }
    private func restartGame() { archiveCurrent();sessionID=UUID().uuidString;UserDefaults.standard.set(sessionID,forKey:"chess.sessionID");cancelMotion();game.reset();selected=nil;inspected=nil;promotionMove=nil;captureText=nil;pendingMove=nil }
    private func playerCard(_ color:ChessColor)->some View {
        let active=game.currentColor == color && !game.isFinished
        return HStack(spacing:7) {
            MagicalChessPiece(piece:ChessPiece(color:color,kind:.king),theme:theme).frame(width:35,height:43)
            VStack(alignment:.leading,spacing:2) {
                Text(color == .white ? "백의 기사단" : "흑의 기사단").font(.subheadline.bold())
                Text(active ? "현재 차례" : color == .white ? "선공" : computer ? "컴퓨터" : "대기").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength:0)
            if active { Circle().fill(theme.accent).frame(width:6,height:6) }
        }.padding(.horizontal,10).padding(.vertical,7).frame(maxWidth:.infinity)
            .background(active ? Color.white.opacity(0.9) : Color.white.opacity(0.45),in:RoundedRectangle(cornerRadius:15))
            .overlay(RoundedRectangle(cornerRadius:15).stroke(active ? Palette.teal : Palette.line,lineWidth:active ? 1.3 : 0.8))
    }
    private var status: String {
        if motion != nil { return motion?.capture == nil ? "기사단이 이동하고 있어요" : "마법의 한 수!" }
        return computerTurn && game.status != "체크메이트" && !game.status.contains("무승부") ? "컴퓨터가 생각하고 있어요…" : game.status
    }
    private func selectSquare(_ index:Int) {
        guard !showBoardMenu,!computerTurn,motion == nil else { return }
        if let from=selected,game.legalMoves(from:from).contains(index) {
            if safeInput { pendingMove=[from,index] } else { commitSelection(from:from,to:index) }
        } else { pendingMove=nil;inspected=game.board[index] == nil ? nil : index;selected=game.board[index]?.color == game.currentColor ? index : nil }
    }
    private func pieceExplanation(_ piece:ChessPiece)->some View {
        HStack(alignment:.top,spacing:12) {
            MagicalChessPiece(piece:piece,theme:theme).frame(width:38,height:44)
            VStack(alignment:.leading,spacing:4) {
                Text("\(piece.color == .white ? "백" : "흑") \(piece.kind.koreanName)").font(.headline).accessibilityIdentifier("chess.selectedPieceName")
                Text(piece.kind.movementDescription).font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("chess.selectedPieceHelp")
            }
            Spacer(minLength:0)
        }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:16))
    }
    private var safeInput:Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--test-direct-board-input") { return false }
        #endif
        return confirmMoves
    }
    private func commitSelection(from:Int,to:Int) {
        pendingMove=nil
        guard !computerTurn,motion == nil,scenePhase == .active,game.legalMoves(from:from).contains(to) else { return }
        if game.board[from]?.kind == .pawn && (to/8 == 0 || to/8 == 7) { promotionMove=[from,to] }
        else { performMove(from:from,to:to) }
    }
    private func moveConfirmation(_ move:[Int])->some View {
        VStack(spacing:8) {
            HStack {
                Text("\(game.board[move[0]]?.kind.koreanName ?? "기물") · \(coordinate(move[0])) → \(coordinate(move[1]))").font(.subheadline.bold()).accessibilityIdentifier("chess.preview")
                Spacer()
                Button("취소") { pendingMove=nil }.frame(minHeight:44).accessibilityIdentifier("chess.cancelPlacement")
            }
            if let capture=game.captureTarget(from:move[0],to:move[1]) { Text("상대 \(capture.piece.kind.koreanName)을 잡는 수입니다").font(.caption).foregroundStyle(Palette.teal) }
            Button("이 수 두기") { commitSelection(from:move[0],to:move[1]) }.buttonStyle(.glassProminent).frame(minHeight:44).accessibilityIdentifier("chess.confirmPlacement")
        }.padding(12).background(Palette.paper,in:RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(Palette.line,lineWidth:0.8))
    }
    private func performMove(from:Int,to:Int,promotion:ChessKind = .queen) {
        guard motion == nil,let attacker=game.board[from] else { return }
        let capture=game.captureTarget(from:from,to:to)
        guard game.move(from:from,to:to,promotion:promotion) else { return }
        selected=nil;inspected=nil
        let event=ChessMotion(from:from,to:to,attacker:attacker,capture:capture)
        captureText=capture == nil ? nil : event.announcement
        // Ordinary moves should land instantly; the battle animation is for captures.
        guard capture != nil,battleEffects,!classicPieces,!reduceMotion,!ProcessInfo.processInfo.arguments.contains("--reduce-chess-motion") else { if capture != nil { impact += 1 };return }
        motion=event;phase=0
        animationTask=Task { @MainActor in
            // Yield one frame so the moving miniature begins at its source square.
            do {
                try await Task.sleep(for:.milliseconds(20))
                guard motion?.id == event.id else { return }
                withAnimation(.easeInOut(duration:0.32)) { phase=1 }
                try await Task.sleep(for:.milliseconds(340))
                guard motion?.id == event.id else { return }
                if capture != nil {
                    impact += 1
                    withAnimation(.easeOut(duration:0.24)) { phase=2 }
                    try await Task.sleep(for:.milliseconds(260))
                    withAnimation(.easeOut(duration:0.3)) { phase=3 }
                    try await Task.sleep(for:.milliseconds(320))
                }
                guard motion?.id == event.id else { return }
                motion=nil;phase=0;animationTask=nil
            } catch { /* Undo, reset, background, and navigation cancel presentation only. */ }
        }
    }
    private func cancelMotion() { animationTask?.cancel();animationTask=nil;motion=nil;phase=0 }
    private func setOpponent(_ useComputer:Bool,_ level:String) {
        pendingMove=nil;cancelMotion();computer=useComputer;difficulty=level;game.reset();selected=nil;inspected=nil;promotionMove=nil;captureText=nil
        UserDefaults.standard.set(useComputer,forKey:"chess.computer");UserDefaults.standard.set(level,forKey:"chess.difficulty")
    }
    private func undoTurn() {
        records.removeAll{$0.id == sessionID};ChessHistory.save(records)
        pendingMove=nil;cancelMotion();let count=game.moveCount;game.undo()
        if computer,count > 0,count.isMultiple(of:2) { game.undo() }
        selected=nil;inspected=nil;promotionMove=nil;captureText=nil
    }
    private func playComputer() async {
        guard !showBoardMenu,!showHistory,computerTurn,motion == nil,scenePhase == .active else { return }
        do { try await Task.sleep(for:.milliseconds(350)) } catch { return }
        let snapshot=game, level=ComputerDifficulty(rawValue:difficulty) ?? .medium
        let worker=Task.detached(priority:.userInitiated) { ComputerOpponent.chessMove(in:snapshot,difficulty:level) }
        let move=await withTaskCancellationHandler { await worker.value } onCancel:{ worker.cancel() }
        guard !Task.isCancelled,!showBoardMenu,!showHistory,computerTurn,motion == nil,scenePhase == .active,game.board == snapshot.board,let move else { return }
        performMove(from:move.from,to:move.to)
    }
    private func coordinate(_ index:Int)->String { "\(Array("abcdefgh")[index%8])\(8-index/8)" }
}
