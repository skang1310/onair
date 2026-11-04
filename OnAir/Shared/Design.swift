import SwiftUI

enum RadioDesign {
    #if os(tvOS)
    static let ink = Color.primary
    static let cream = Color.black
    static let surface = Color.gray.opacity(0.2)
    #else
    static let ink = Color("RadioInk")
    static let cream = Color("RadioBackground")
    static let surface = Color("RadioSurface")
    #endif
    static let coral = Color(red: 1, green: 0.43, blue: 0.08)
    static let colors: [Color] = [coral, Color(red: 0.22, green: 0.39, blue: 0.39), Color(red: 0.33, green: 0.34, blue: 0.62), Color(red: 0.65, green: 0.38, blue: 0.18)]
}

struct StationArtwork: View {
    var station: Station
    var large = false
    var cornerRadius: CGFloat? = nil
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack {
                Rectangle().fill(RadioDesign.colors[station.palette].gradient)
                Circle().stroke(.white.opacity(0.12), lineWidth: width * 0.12).frame(width: width * 0.85).offset(x: width * 0.28, y: -width * 0.22)
                Circle().stroke(.white.opacity(0.1), lineWidth: width * 0.025).frame(width: width * 0.65).offset(x: -width * 0.34, y: width * 0.31)
                VStack(alignment: .leading, spacing: 8) {
                    if large {
                        HStack { Text("ON AIR / SEOUL").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2); Spacer(); Image(systemName: "dot.radiowaves.left.and.right") }
                        Spacer()
                    }
                    if let logo = station.logoAsset {
                        Image(logo).renderingMode(.original).resizable().scaledToFit()
                            .padding(width * 0.04)
                            .frame(width: width * 0.73, height: width * (large ? 0.25 : 0.38))
                            .background(logo == "StationLogoMBC" ? Color(red: 0.12, green: 0.14, blue: 0.2) : Color.white, in: .rect(cornerRadius: width * 0.04))
                    } else {
                        Image(systemName: "waveform").font(.system(size: width * 0.25, weight: .light))
                    }
                    if large {
                        Spacer()
                        Text(station.name).font(.system(size: width * 0.105, weight: .bold)).lineLimit(2).minimumScaleFactor(0.6)
                        Text("YOUR EVERYDAY FREQUENCY").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.2)
                    }
                }.padding(width * 0.085)
            }.foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: cornerRadius ?? (large ? 30 : 16)))
        }.aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct LiveBadge: View {
    var body: some View {
        HStack(spacing: 5) { Circle().fill(RadioDesign.coral).frame(width: 5, height: 5); Text("실시간 방송").font(.caption2.weight(.semibold)) }
    }
}
