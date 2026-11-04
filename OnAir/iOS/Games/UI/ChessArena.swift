import SwiftUI

struct ChessProjection {
    let width: CGFloat
    var flat = false
    func point(column: CGFloat, row: CGFloat) -> CGPoint {
        if flat { return CGPoint(x:width*(0.025+column*0.95/8),y:width*(0.025+row*0.95/8)) }
        let t = row/8
        return CGPoint(x:width/2 + (column/8-0.5)*width*(0.74+0.20*t),y:width*(0.12+0.76*t))
    }
    func rect(_ square: Int) -> CGRect {
        let points=corners(square), xs=points.map(\.x), ys=points.map(\.y)
        return CGRect(x:xs.min()!,y:ys.min()!,width:xs.max()!-xs.min()!,height:ys.max()!-ys.min()!)
    }
    func localCorners(_ square:Int)->[CGPoint] { let rect=rect(square);return corners(square).map { CGPoint(x:$0.x-rect.minX,y:$0.y-rect.minY) } }
    func center(_ square: Int) -> CGPoint { point(column:CGFloat(square%8)+0.5,row:CGFloat(square/8)+0.5) }
    func corners(_ square: Int) -> [CGPoint] {
        let row=CGFloat(square/8), col=CGFloat(square%8)
        return [point(column:col,row:row),point(column:col+1,row:row),point(column:col+1,row:row+1),point(column:col,row:row+1)]
    }
}
private struct ArenaPolygon: Shape {
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path { var path=Path();path.addLines(points);path.closeSubpath();return path }
}

struct ChessArena: View {
    @AppStorage("chess.classicPieces") private var classicPieces = true
    let game: ChessGame
    let theme: ChessTheme
    let showLastMove: Bool
    let selected: Int?
    let motion: ChessMotion?
    let phase: Double
    let locked: Bool
    let select: (Int) -> Void
    var flatBoard = true
    var pending: Int? = nil
    var body: some View {
        GeometryReader { geo in
            let projection = ChessProjection(width:geo.size.width,flat:flatBoard)
            let w = geo.size.width
            // These values belong to the position, not to each of the 64 cells.
            let lastMove = showLastMove ? game.lastMove : nil
            let legal = selected.map { game.legalMoves(from:$0) } ?? []
            ZStack(alignment:.topLeading) {
                RoundedRectangle(cornerRadius:24).fill(LinearGradient(colors:[theme.dark.opacity(0.94),theme.dark.opacity(0.7)],startPoint:.top,endPoint:.bottom))
                // A thick front edge and narrowing far edge make a physical tabletop.
                if !flatBoard {
                ArenaPolygon(points:[projection.point(column:0,row:8),projection.point(column:8,row:8),CGPoint(x:projection.point(column:8,row:8).x,y:w*0.92),CGPoint(x:projection.point(column:0,row:8).x,y:w*0.92)]).fill(theme.dark).overlay(ArenaPolygon(points:[projection.point(column:0,row:8),projection.point(column:8,row:8),CGPoint(x:projection.point(column:8,row:8).x,y:w*0.92),CGPoint(x:projection.point(column:0,row:8).x,y:w*0.92)]).stroke(theme.accent.opacity(0.35),lineWidth:1))
                }
                ForEach(0..<64) { index in
                    ArenaPolygon(points:projection.corners(index)).fill((index/8+index%8).isMultiple(of:2) ? theme.light : theme.dark)
                        .overlay(ArenaPolygon(points:projection.corners(index)).stroke(.black.opacity(0.13),lineWidth:0.5))
                    if lastMove?.from == index { ArenaPolygon(points:projection.corners(index)).stroke(theme.accent,style:StrokeStyle(lineWidth:2,dash:[4,3])) }
                    if lastMove?.to == index { ArenaPolygon(points:projection.corners(index)).fill(theme.accent.opacity(0.25)); ArenaPolygon(points:projection.corners(index)).stroke(theme.accent,lineWidth:2) }
                    if pending == index { ArenaPolygon(points:projection.corners(index)).fill(Color.cyan.opacity(0.28));ArenaPolygon(points:projection.corners(index)).stroke(.white,lineWidth:3) }
                    if selected == index { ArenaPolygon(points:projection.corners(index)).fill(Color.cyan.opacity(0.35)); ArenaPolygon(points:projection.corners(index)).stroke(.white,lineWidth:2) }
                    if legal.contains(index) {
                        Circle().fill(theme.accent).frame(width:w*0.025,height:w*0.018).position(projection.center(index)).shadow(color:.black.opacity(0.5),radius:2)
                    }
                }
                ForEach(0..<64) { index in
                    if let piece = visiblePiece(index) {
                        MagicalChessPiece(piece:piece,theme:theme)
                            .frame(width:w*0.105,height:w*(flatBoard ? 0.11 : 0.14))
                            .rotationEffect(.degrees(motion?.capture?.square == index && phase >= 2 ? 75 : 0))
                            .scaleEffect(motion?.capture?.square == index && phase >= 2 ? 0.25 : 1)
                            .opacity(motion?.capture?.square == index && phase >= 2 ? 0 : 1)
                            .position(x:projection.center(index).x,y:projection.center(index).y-(classicPieces ? 0 : w*(flatBoard ? 0.012 : 0.06)))
                            .zIndex(Double(index/8+1))
                    }
                }
                if let motion {
                    movingPiece(motion, projection:projection, width:w).zIndex(20)
                    if motion.capture != nil { battleEffect(motion,projection:projection,width:w).zIndex(21) }
                }
                ForEach(0..<64) { index in
                    let rect=projection.rect(index)
                    Button { select(index) } label: { ArenaPolygon(points:projection.localCorners(index)).fill(Color.white.opacity(0.001)).contentShape(ArenaPolygon(points:projection.localCorners(index))) }.frame(width:rect.width,height:rect.height).position(x:rect.midX,y:rect.midY)
                        .buttonStyle(.plain).disabled(locked).accessibilityElement(children:.ignore).accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("chess.cell.\(index/8).\(index%8)")
                        .accessibilityLabel(label(index,lastMove:lastMove,legal:legal)).zIndex(30)
                }
                ForEach(0..<8) { column in
                    Text(String(Array("abcdefgh")[column])).font(.system(size:10,weight:.semibold)).foregroundStyle(theme.accent).position(x:projection.point(column:CGFloat(column)+0.5,row:8).x,y:w*(flatBoard ? 0.989 : 0.95))
                    Text("\(8-column)").font(.system(size:9,weight:.medium)).foregroundStyle(theme.accent).position(x:flatBoard ? w*0.012 : projection.point(column:0,row:CGFloat(column)+0.5).x-8,y:projection.center(column*8).y)
                }
            }.frame(width:w,height:geo.size.height).clipShape(RoundedRectangle(cornerRadius:24)).shadow(color:theme.dark.opacity(0.3),radius:15,y:9)
        }.aspectRatio(1,contentMode:.fit).accessibilityElement(children:.contain)
    }
    private func visiblePiece(_ index: Int) -> ChessPiece? {
        if let motion {
            if motion.to == index { return motion.capture?.square == index ? motion.capture?.piece : nil }
            if motion.capture?.square == index { return motion.capture?.piece }
            if motion.from == index { return nil }
        }
        return game.board[index]
    }
    private func movingPiece(_ motion: ChessMotion, projection: ChessProjection, width:CGFloat) -> some View {
        let from=projection.center(motion.from),to=projection.center(motion.to)
        let progress=min(1,phase)
        return MagicalChessPiece(piece:motion.attacker,theme:theme)
            .frame(width:width*0.112,height:width*(flatBoard ? 0.11 : 0.15))
            .rotationEffect(.degrees(phase >= 2 && phase < 3 ? (motion.attacker.kind == .knight ? -17 : 12) : 0))
            .scaleEffect(phase >= 2 && phase < 3 ? 1.12 : 1)
            .position(x:from.x+(to.x-from.x)*progress,y:from.y+(to.y-from.y)*progress-width*(flatBoard ? 0.012 : 0.065))
    }
    private func battleEffect(_ motion: ChessMotion, projection: ChessProjection, width:CGFloat) -> some View {
        let point=projection.center(motion.capture!.square)
        let spell=[ChessKind.bishop,.queen,.king].contains(motion.attacker.kind)
        return ZStack {
            Circle().stroke(theme.accent.opacity(0.9),lineWidth:3).frame(width:width*0.15,height:width*(flatBoard ? 0.11 : 0.15)).scaleEffect(phase >= 3 ? 2 : 0.3).opacity(phase >= 2 && phase < 3 ? 1 : 0)
            Image(systemName:spell ? "wand.and.stars" : "bolt.shield.fill").font(.system(size:width*0.13)).foregroundStyle(theme.accent).rotationEffect(.degrees(phase >= 2 ? 25 : -35)).opacity(phase >= 2 && phase < 3 ? 1 : 0).offset(y:-width*0.07)
            ForEach(0..<12) { i in
                let angle=Double(i)*Double.pi/6
                RoundedRectangle(cornerRadius:2).fill(i.isMultiple(of:2) ? theme.accent : theme.light)
                    .frame(width:width*0.022,height:width*0.014)
                    .rotationEffect(.degrees(Double(i)*37 + phase*25))
                    .offset(x:CGFloat(cos(angle))*width*(phase >= 3 ? 0.19 : 0.04),y:CGFloat(sin(angle))*width*(phase >= 3 ? 0.13 : 0.025))
                    .opacity(phase >= 2 && phase < 3 ? 1 : 0)
            }
        }.position(point).allowsHitTesting(false).accessibilityHidden(true)
    }
    private func label(_ index:Int,lastMove:ChessGame.LastMove?,legal:[Int])->String {
        "\(Array("abcdefgh")[index%8])\(8-index/8), \(game.board[index].map { "\($0.color == .white ? "백" : "흑") \($0.kind.koreanName)" } ?? "빈 칸")\(lastMove?.from == index ? ", 직전 출발 칸" : lastMove?.to == index ? ", 직전 도착 칸" : "")\(legal.contains(index) ? ", 이동 가능" : "")"
    }
}
