import SwiftUI

enum ChessTheme: String, CaseIterable, Identifiable {
    case castle, crystal, forest
    var id: String { rawValue }
    var title: String { switch self { case .castle: "고대 성채"; case .crystal: "달빛 수정"; case .forest: "마법의 숲" } }
    var caption: String { switch self { case .castle: "깨어나는 석상 기사단"; case .crystal: "빛으로 부서지는 수정 군단"; case .forest: "숲을 지키는 나무 정령들" } }
    var atlas: String { "Chess" + rawValue.capitalized + "Atlas" }
    var light: Color { switch self { case .castle: Color(red:0.78,green:0.72,blue:0.58); case .crystal: Color(red:0.71,green:0.79,blue:0.89); case .forest: Color(red:0.74,green:0.78,blue:0.59) } }
    var dark: Color { switch self { case .castle: Color(red:0.30,green:0.32,blue:0.34); case .crystal: Color(red:0.28,green:0.27,blue:0.48); case .forest: Color(red:0.22,green:0.36,blue:0.28) } }
    var accent: Color { switch self { case .castle: Color(red:0.95,green:0.74,blue:0.36); case .crystal: Color(red:0.55,green:0.82,blue:1); case .forest: Color(red:0.67,green:0.93,blue:0.55) } }
}
enum GomokuTheme: String, CaseIterable, Identifiable {
    case wood, jade, night
    var id: String { rawValue }
    var title: String { switch self { case .wood: "따뜻한 나무"; case .jade: "백옥 정원"; case .night: "별빛 호수" } }
    var texture: String { switch self { case .wood: "BoardWoodRealistic"; case .jade: "GomokuJadeSurface"; case .night: "GomokuNightSurface" } }
    var line: Color { self == .night ? Color(red:0.77,green:0.84,blue:0.98) : Color(red:0.20,green:0.25,blue:0.25) }
    var accent: Color { self == .night ? .cyan : Palette.teal }
}

struct BoardThemePicker: View {
    let title: String
    let entries: [(id: String, title: String, color: Color)]
    @Binding var selection: String
    var disabled = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary); Spacer(); Text("\(entries.count) THEMES").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary) }
            HStack(spacing: 8) {
                ForEach(entries, id: \.id) { entry in
                    Button { selection = entry.id } label: {
                        HStack(spacing: 6) { Circle().fill(entry.color).frame(width: 9, height: 9); Text(entry.title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8); if selection == entry.id { Image(systemName: "checkmark").font(.caption2.bold()) } }
                            .padding(.horizontal, 10).frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(Palette.ink).background(selection == entry.id ? Color.white : Color.white.opacity(0.4), in: Capsule()).overlay(Capsule().stroke(selection == entry.id ? Palette.indigo.opacity(0.4) : .clear))
                    }.buttonStyle(.plain).disabled(disabled).accessibilityIdentifier("theme.\(entry.id)").accessibilityAddTraits(selection == entry.id ? .isSelected : [])
                }
            }
        }
    }
}

@MainActor
enum ChessArtwork {
    private static var cache: [String: UIImage] = [:]
    static func image(_ piece: ChessPiece, theme: ChessTheme) -> UIImage {
        let key = theme.rawValue + piece.color.rawValue + piece.kind.rawValue
        if let image = cache[key] { return image }
        guard let atlas = UIImage(named: theme.atlas)?.cgImage else { assertionFailure("Missing \(theme.atlas)"); return UIImage() }
        let kinds: [ChessKind] = [.pawn,.knight,.bishop,.rook,.queen,.king]
        let column = kinds.firstIndex(of: piece.kind)!
        let width = atlas.width / 6, height = atlas.height / 2
        guard let crop = atlas.cropping(to: CGRect(x:column*width,y:(piece.color == .white ? 0 : height),width:width,height:height)) else { return UIImage() }
        let image = isolatedSprite(crop)
        cache[key] = image; return image
    }
    static func classicImage(_ piece:ChessPiece)->UIImage {
        let key="classic2D"+piece.color.rawValue+piece.kind.rawValue
        if let cached=cache[key] { return cached }
        guard let atlas=UIImage(named:"ChessClassic2DAtlas")?.cgImage else { return image(piece,theme:.castle) }
        let kinds:[ChessKind]=[.pawn,.knight,.bishop,.rook,.queen,.king]
        let w=atlas.width/6,h=atlas.height/2
        guard let crop=atlas.cropping(to:CGRect(x:kinds.firstIndex(of:piece.kind)!*w,y:piece.color == .white ? 0 : h,width:w,height:h)) else { return UIImage() }
        let sprite=isolatedSprite(crop)
        guard let cg=sprite.cgImage else { return sprite }
        var pixels=[UInt8](repeating:0,count:cg.width*cg.height*4)
        let result:UIImage=pixels.withUnsafeMutableBytes { raw in
            guard let ctx=CGContext(data:raw.baseAddress,width:cg.width,height:cg.height,bitsPerComponent:8,bytesPerRow:cg.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return sprite }
            ctx.draw(cg,in:CGRect(x:0,y:0,width:cg.width,height:cg.height))
            let bytes=raw.bindMemory(to:UInt8.self)
            var minX=cg.width,minY=cg.height,maxX=0,maxY=0
            for y in 0..<cg.height { for x in 0..<cg.width where bytes[(y*cg.width+x)*4+3] > 15 { minX=min(minX,x);maxX=max(maxX,x);minY=min(minY,y);maxY=max(maxY,y) } }
            guard maxX >= minX,maxY >= minY,let trim=cg.cropping(to:CGRect(x:minX,y:minY,width:maxX-minX+1,height:maxY-minY+1)) else { return sprite }
            return UIImage(cgImage:trim)
        }
        cache[key]=result;return result
    }
    /// Keep the main connected silhouette in each atlas cell; discard tiny
    /// detached fragments belonging to neighboring miniatures. Preserve canvas
    /// dimensions so all bases remain aligned during movement.
    static func isolatedSprite(_ cg: CGImage) -> UIImage {
        let w=cg.width,h=cg.height
        var pixels=[UInt8](repeating:0,count:w*h*4)
        return pixels.withUnsafeMutableBytes { raw in
            guard let context=CGContext(data:raw.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return UIImage(cgImage:cg) }
            context.draw(cg,in:CGRect(x:0,y:0,width:w,height:h))
            let bytes=raw.bindMemory(to:UInt8.self)
            var labels=[Int](repeating:0,count:w*h),label=0,best=0,bestSize=0
            for start in 0..<w*h where labels[start] == 0 && bytes[start*4+3] > 8 {
                label += 1
                var queue=[start],cursor=0;labels[start]=label
                while cursor < queue.count {
                    let i=queue[cursor];cursor += 1
                    let x=i%w,y=i/w
                    for (dx,dy) in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,1),(-1,1),(1,-1)] {
                        let xx=x+dx,yy=y+dy
                        guard xx >= 0,xx < w,yy >= 0,yy < h else { continue }
                        let n=yy*w+xx
                        if labels[n] == 0 && bytes[n*4+3] > 8 { labels[n]=label;queue.append(n) }
                    }
                }
                if queue.count > bestSize { bestSize=queue.count;best=label }
            }
            for i in 0..<w*h where labels[i] != best { bytes[i*4]=0;bytes[i*4+1]=0;bytes[i*4+2]=0;bytes[i*4+3]=0 }
            guard let clean=context.makeImage() else { return UIImage(cgImage:cg) }
            return UIImage(cgImage:clean)
        }
    }
}
struct MagicalChessPiece: View {
    let piece: ChessPiece
    let theme: ChessTheme
    @AppStorage("chess.classicPieces") private var classicPieces = true
    var body: some View {
        Image(uiImage: classicPieces ? ChessArtwork.classicImage(piece) : ChessArtwork.image(piece, theme: theme)).resizable().scaledToFit().shadow(color: .black.opacity(classicPieces ? 0 : 0.55), radius: 2, x: 1, y: 3).accessibilityHidden(true)
    }
}

extension ChessKind {
    var movementDescription:String {
        switch self {
        case .pawn:"앞으로 한 칸 이동합니다. 처음에는 두 칸도 가능하며, 상대 말은 앞 대각선으로 잡습니다. 끝에 도착하면 승격합니다."
        case .knight:"가로 두 칸·세로 한 칸, 또는 그 반대로 L자 이동합니다. 다른 말을 뛰어넘을 수 있습니다."
        case .bishop:"대각선으로 원하는 만큼 이동합니다. 다른 말을 뛰어넘을 수 없습니다."
        case .rook:"가로 또는 세로로 원하는 만큼 이동합니다. 다른 말을 뛰어넘을 수 없습니다."
        case .queen:"가로·세로·대각선으로 원하는 만큼 이동합니다. 다른 말을 뛰어넘을 수 없습니다."
        case .king:"모든 방향으로 한 칸 이동합니다. 상대에게 공격받는 칸으로는 갈 수 없습니다. 조건이 맞으면 캐슬링할 수 있습니다."
        }
    }
}
