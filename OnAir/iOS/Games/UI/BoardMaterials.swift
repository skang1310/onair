import SwiftUI
import SpriteKit

/// Material images are cached once; transparent margins are excluded from sprite bounds.
/// This keeps the visible silhouette aligned with the existing collision radius.
@MainActor
enum BoardMaterials {
    static let wood = "BoardWoodRealistic"
    static let ice = "BoardIceRealistic"
    static let felt = "BoardFeltRealistic"
    private static var images:[String:UIImage] = [:]
    private static var textures:[String:SKTexture] = [:]
    static func stoneName(_ player:Int)->String { player == 1 ? "StoneBlackRealistic":"StoneWhiteRealistic" }
    static func image(_ name:String,cutout:Bool = false)->UIImage {
        let key = name+(cutout ? ".cutout":".full")
        if let image = images[key] { return image }
        guard let image = UIImage(named:name) else { assertionFailure("Missing game material: \(name)"); return UIImage() }
        let prepared = cutout ? trimTransparentMargin(image):image
        images[key] = prepared; return prepared
    }
    static func texture(_ name:String,cutout:Bool = false)->SKTexture {
        let key = name+(cutout ? ".cutout":".full")
        if let texture = textures[key] { return texture }
        let texture = SKTexture(image:image(name,cutout:cutout)); texture.filteringMode = .linear
        textures[key] = texture; return texture
    }
    private static func trimTransparentMargin(_ image:UIImage)->UIImage {
        guard let cg = image.cgImage else { return image }
        let w = cg.width,h = cg.height
        var pixels = [UInt8](repeating:0,count:w*h*4)
        let bounds:CGRect? = pixels.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data:buffer.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            ctx.draw(cg,in:CGRect(x:0,y:0,width:w,height:h))
            let bytes = buffer.bindMemory(to:UInt8.self)
            var minX = w,minY = h,maxX = -1,maxY = -1
            for y in 0..<h { for x in 0..<w where bytes[(y*w+x)*4+3] > 48 {
                minX = min(minX,x); maxX = max(maxX,x); minY = min(minY,y); maxY = max(maxY,y)
            } }
            guard maxX >= minX,maxY >= minY else { return nil }
            // Keep a few antialiased edge pixels; the generated sprite remains circular.
            minX = max(0,minX-2); minY = max(0,minY-2); maxX = min(w-1,maxX+2); maxY = min(h-1,maxY+2)
            return CGRect(x:minX,y:minY,width:maxX-minX+1,height:maxY-minY+1)
        }
        guard let bounds,let cropped = cg.cropping(to:bounds) else { return image }
        return UIImage(cgImage:cropped,scale:image.scale,orientation:.up)
    }
}

struct RealisticGoStone:View {
    let player:Int
    var body:some View {
        Image(uiImage:BoardMaterials.image(BoardMaterials.stoneName(player),cutout:true))
            .resizable().scaledToFit().shadow(color:.black.opacity(0.28),radius:1.2,x:0.5,y:1.5)
            .accessibilityHidden(true)
    }
}
