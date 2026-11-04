import SwiftUI
import UIKit

struct HapticGlassTuner: View {
    @Bindable var library: StationLibrary
    @Bindable var player: RadioPlayer
    @State private var currentFrequency: Double = 93.9
    @State private var isDragging: Bool = false
    @State private var lastHapticStep: Int = -1

    private let minFreq: Double = 88.0
    private let maxFreq: Double = 108.0
    private let step: Double = 0.2

    // 주파수 프리셋 목록
    private let presets: [(freq: Double, name: String, key: String)] = [
        (89.1, "KBS Cool", "kbscoolfm"),
        (91.9, "MBC 4U", "mbcfm4u"),
        (93.1, "KBS 클래식", "kbsclassicfm"),
        (93.9, "CBS 음악", "cbsmusic"),
        (95.9, "MBC 표준", "mbcstandard"),
        (97.3, "KBS 1R", "kbs1radio"),
        (98.1, "CBS 표준", "cbsstandard"),
        (103.5, "SBS 러브", "sbslove"),
        (107.7, "SBS 파워", "sbspower")
    ]

    var body: some View {
        VStack(spacing: 16) {
            // 상단: ON AIR 라이브 뱃지 & 주파수 수치
            HStack(alignment: .center) {
                // 1번 아이콘 콘셉트: ON AIR 라이브 뱃지
                HStack(spacing: 6) {
                    Circle()
                        .fill(player.isPlaying ? Color.red : Color.gray.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .shadow(color: player.isPlaying ? Color.red.opacity(0.8) : .clear, radius: 4)
                    Text("ON AIR")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(player.isPlaying ? Color.red : Color.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(player.isPlaying ? Color.red.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                )

                Spacer()

                // 현재 주파수 및 방송국명
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", currentFrequency))
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .foregroundStyle(LiquidRadioTheme.accent)
                        Text("MHz")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Text(matchedStationName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.primary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)

            // 중앙: 햅틱 글래스 튜너 눈금 다이얼
            ZStack(alignment: .center) {
                // 반투명 리퀴드 글래스 베이스
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)

                // 주파수 눈금자 렌더링
                GeometryReader { geo in
                    let width = geo.size.width
                    let totalSteps = Int((maxFreq - minFreq) / step)
                    let currentProgress = CGFloat((currentFrequency - minFreq) / (maxFreq - minFreq))
                    let contentWidth = CGFloat(totalSteps) * 14.0
                    let offsetX = (width / 2.0) - (currentProgress * contentWidth)

                    HStack(alignment: .center, spacing: 14) {
                        ForEach(0...totalSteps, id: \.self) { idx in
                            let freq = minFreq + Double(idx) * step
                            let isMajor = (idx % 5 == 0) // 1.0 MHz 단위
                            let hasStation = presets.contains { abs($0.freq - freq) < 0.05 }

                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(
                                        hasStation ? LiquidRadioTheme.accent :
                                        (isMajor ? Color.primary.opacity(0.6) : Color.primary.opacity(0.2))
                                    )
                                    .frame(width: isMajor ? 2 : 1.2, height: isMajor ? 28 : (hasStation ? 22 : 14))

                                if isMajor {
                                    Text(String(format: "%.0f", freq))
                                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(Color.secondary)
                                } else {
                                    Spacer().frame(height: 12)
                                }
                            }
                            .frame(width: 4)
                        }
                    }
                    .frame(width: contentWidth, height: geo.size.height)
                    .offset(x: offsetX)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let deltaX = value.translation.width
                                let freqDelta = -Double(deltaX / contentWidth) * (maxFreq - minFreq)
                                let newFreq = max(minFreq, min(maxFreq, currentFrequency + freqDelta))
                                updateFrequency(newFreq)
                            }
                            .onEnded { _ in
                                isDragging = false
                                snapToNearestStationIfClose()
                            }
                    )
                }
                .frame(height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // 중앙 앰버 인디케이터 바늘 (Glow Needle)
                VStack(spacing: 0) {
                    Circle()
                        .fill(LiquidRadioTheme.accent)
                        .frame(width: 6, height: 6)
                        .shadow(color: LiquidRadioTheme.accent.opacity(0.8), radius: 4)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [LiquidRadioTheme.accent, LiquidRadioTheme.accent.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 50)
                        .shadow(color: LiquidRadioTheme.accent.opacity(0.7), radius: 6)
                }
                .allowsHitTesting(false)
            }

            // 하단: 주파수 퀵 프리셋 칩 (애플 글래스 캡슐)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.key) { preset in
                        let isSelected = abs(currentFrequency - preset.freq) < 0.15
                        Button {
                            tuneToPreset(preset)
                        } label: {
                            HStack(spacing: 5) {
                                Text(String(format: "%.1f", preset.freq))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(isSelected ? LiquidRadioTheme.accent : .secondary)
                                Text(preset.name)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                    .foregroundStyle(isSelected ? .primary : .secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                isSelected ? LiquidRadioTheme.accent.opacity(0.12) : Color.primary.opacity(0.04),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        isSelected ? LiquidRadioTheme.accent.opacity(0.4) : Color.primary.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(.ultraThinMaterial.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .onAppear {
            syncFromPlayer()
        }
        .onChange(of: player.station?.id) { _, _ in
            syncFromPlayer()
        }
    }

    private var matchedStationName: String {
        if let found = presets.first(where: { abs($0.freq - currentFrequency) < 0.15 }) {
            return found.name
        }
        if let st = library.stations.first(where: {
            guard let f = RadioFrequency.values[$0.catalogKey] else { return false }
            return abs(f - currentFrequency) < 0.15
        }) {
            return st.name
        }
        return "주파수 탐색"
    }

    private func updateFrequency(_ newFreq: Double) {
        let rounded = (newFreq * 10).rounded() / 10
        if rounded != currentFrequency {
            currentFrequency = rounded
            triggerHapticFeedback(for: rounded)
        }
    }

    private func triggerHapticFeedback(for freq: Double) {
        let stepIndex = Int((freq - minFreq) / step)
        if stepIndex != lastHapticStep {
            lastHapticStep = stepIndex
            let isStation = presets.contains { abs($0.freq - freq) < 0.05 }
            let generator = UIImpactFeedbackGenerator(style: isStation ? .rigid : .light)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    private func tuneToPreset(_ preset: (freq: Double, name: String, key: String)) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            currentFrequency = preset.freq
        }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // 일치하는 방송국 재생
        if let targetStation = library.stations.first(where: { $0.catalogKey == preset.key }) ??
                                Station.curated.first(where: { $0.catalogKey == preset.key }) {
            player.play(targetStation)
        }
    }

    private func snapToNearestStationIfClose() {
        if let closest = presets.first(where: { abs($0.freq - currentFrequency) < 0.25 }) {
            tuneToPreset(closest)
        }
    }

    private func syncFromPlayer() {
        guard !isDragging, let st = player.station else { return }
        if let f = RadioFrequency.values[st.catalogKey] {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentFrequency = f
            }
        }
    }
}
