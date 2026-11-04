# 온에어

한국 라디오를 위한 SwiftUI iPhone · Apple Watch · Apple TV 앱. iPhone은 홈·방송국·보관함 탭, 보라/청록 그래디언트 방송 카드, 시스템 Liquid Glass 탭·툴바·재생 버튼을 사용합니다. 회전 휠과 노래 찾기는 제거했습니다.

## 실행

`OnAir.xcodeproj`를 Xcode 27에서 열고 `OnAir`(iPhone 단독), `OnAirWithWatch`(Watch 포함 패키지), `OnAirWatch`, `OnAirTV` 스킴과 해당 시뮬레이터를 선택하세요. 프로젝트 원본은 `project.yml`; 재생성은 `xcodegen generate`입니다. 최소 OS는 26이며 27 SDK에서 컴파일합니다. 실제 기기에 설치하려면 각 타깃의 Signing Team과 App Group을 자신의 계정으로 설정해야 합니다. 기본 `OnAir` 스킴은 iPhone 앱과 iPhone 위젯만 빌드하므로 Watch 프로파일이 없어도 iPhone에 실행할 수 있습니다. `OnAirWithWatch`는 Watch 앱과 Watch 위젯까지 포함하며 두 Watch 타깃의 개발 프로파일이 별도로 필요합니다.

```sh
xcodebuild -project OnAir.xcodeproj -scheme OnAir -destination 'generic/platform=iOS Simulator' -derivedDataPath build/iOS CODE_SIGNING_ALLOWED=NO build
xcodebuild -project OnAir.xcodeproj -scheme OnAirTV -destination 'generic/platform=tvOS Simulator' -derivedDataPath build/TV CODE_SIGNING_ALLOWED=NO build
```

## 구현된 기능

- iPhone: 홈·방송국·보관함, 뉴스·시사 탐색 화면, 검색/장르 필터, 즐겨찾기, 미니 플레이어, 전체 재생 화면, 이전/다음 방송, 취침 타이머, AirPlay 선택, 기상 알람, 탁상 시계, 방송 카드 공유.
- 공통: AVPlayer 스트리밍, 백그라운드 오디오, 서버 응답 확인, 25초 연결 제한과 최대 3회 자동 재연결, 방송 목록 캐시 및 서버 대체, 취소된 요청이 다음 방송을 덮어쓰지 않는 재생 처리.
- KBS: Cool FM, Classic FM, 1R/2R/3R은 공식 공개 서비스에서 재생 직전에 최신 HLS 주소를 조회.
- iPhone: 잠금화면 시스템 Now Playing/원격 재생·정지, Live Activity와 Dynamic Island, Siri/App Shortcut ‘온에어 라디오 틀어 줘’.
- WidgetKit: iPhone 홈 화면 small/medium, 잠금화면 circular/rectangular/inline. circular/rectangular 및 홈 위젯의 직접 재생·정지, medium 위젯의 즐겨찾기 재생. inline은 딥링크. 최근 방송 또는 출근/퇴근/취침 프리셋 선택 설정.
- 스탠바이: 침대 옆 라디오 small/medium 위젯. 시계, 방송명, 재생 버튼, 취침 프리셋 및 남은 타이머. 시스템이 배경을 제거할 수 있도록 구성하며 StandBy 야간 적색 모드는 시스템에서 관리합니다.
- Watch: 독립 재생 또는 iPhone 원격 제어 모드. 방송 변경/재생·정지/취침 타이머, 즐겨찾기 동기화, Smart Stack 위젯 및 complications.
- TV: 리모컨 포커스를 지원하는 방송 카드, 큰 재생 화면, 즐겨찾기, 취침 타이머.

위젯의 AudioPlaybackIntent는 앱 프로세스에서 재생을 제어합니다. App Group은 같은 기기의 앱/위젯 저장소입니다. 기기 간 즐겨찾기는 iPhone–Watch의 WatchConnectivity, iPhone–TV의 iCloud KVS로 별도 처리합니다. 삭제 변경 기록을 포함한 항목별 병합을 사용합니다. 동일한 Apple 계정이 필요하며 iCloud 실기기 검증은 남아 있습니다.

## iOS 27에 관하여

현재 머신의 Xcode 27.0 (27A266a), iOS/watchOS/tvOS 27 SDK를 사용했습니다. watchOS 27에서 새로 제공되는 SwiftUI `reorderable` / `reorderContainer`를 워치 즐겨찾기 순서 편집에 사용합니다. OS 26에서는 이 편집 화면을 노출하지 않습니다. Liquid Glass·WidgetKit·StandBy·ActivityKit·App Intents는 확인된 공개 API로 구현했습니다.

## 방송 데이터와 제한

[Radio Browser](https://docs.radio-browser.info/) 한국 공개 디렉터리를 HTTPS로 조회합니다. 포함된 `stations.json`은 2026-10-06 목록 스냅샷이며 런타임에 갱신됩니다. 모든 방송국의 청취 가능성을 보장하지 않습니다. 일부 MBC/SBS 공개 디렉터리 주소는 점검 시 만료되어 400/403 응답을 반환했고 자동 토큰 갱신은 지원하지 않습니다. 방송사별 제한, 지역, 네트워크, 주소 만료에 따라 실패할 수 있습니다. 앱에 오류 안내와 방송사 사이트 링크가 있습니다.

CBS 공식 오늘 편성표를 조회해 실제 프로그램 이름과 시간을 표시합니다. CBS 외 방송사는 공식 편성표 링크를 제공합니다. 프로그램을 저장하면 확인된 오늘의 미래 방송에 시작 5분 전 알림을 예약하며, 앱을 열어 편성표를 갱신할 때 다음 알림을 다시 예약합니다. 서버에서 매일 알림을 푸시하는 서비스는 아닙니다. 현재 곡, DJ, 청취자 수를 만들어 표시하지 않으며 녹음이나 다운로드 기능은 없습니다.

## 추가된 1–8번 기능

1. 방송 서버 응답 상태와 연결 끊김 자동 재연결. 목록을 길게 누르거나 재생 화면에서 직접 확인합니다.
2. iPhone–Watch 즐겨찾기 동기화, iCloud KVS를 통한 iPhone–TV 동기화 코드와 전용 스킴.
3. CBS 실제 편성표, 프로그램 저장, 오늘 방송 시작 5분 전 알림 및 알림 탭 시 재생.
4. 종합 뉴스/경제/시사 토론/지역 뉴스 프로그램 분류, 방송사 필터와 지역 방송국 탐색.
5. 출근/퇴근/취침 프리셋. 내 라디오에서 방송과 종료 시간을 수정합니다.
6. Watch에서 iPhone 방송 변경, 재생·정지 및 취침 타이머 제어. 연결 실패/응답 제한 안내.
7. 직접 재생·정지 가능한 iPhone/Watch 위젯 및 프리셋 설정.
8. 어두운 기본 배경의 침대 옆 라디오 위젯. StandBy에서 추가하고 사용합니다.

## iCloud 서명 설정

기존 iPhone 개발 프로파일에 iCloud 권한이 없고 Xcode에 개발 Apple 계정이 로그인되지 않아 새 프로파일 자동 생성은 실패했습니다. 기본 `OnAir` / `OnAirWithWatch` 스킴은 기존 프로파일로 서명되도록 iCloud entitlement를 제외합니다. 이 빌드에서는 iPhone–Watch 동기화를 사용합니다.

`OnAirCloud` / `OnAirCloudWithWatch` 스킴은 `CLOUD_SYNC`와 `com.apple.developer.ubiquity-kvstore-identifier`를 켭니다. Xcode에서 개발 계정 로그인 후 앱 ID의 iCloud Key-Value Storage를 활성화하고 프로파일을 갱신해야 실물 배포할 수 있습니다. Watch 포함 스킴은 Watch 두 타깃 프로파일도 필요합니다. `OnAirTV`는 같은 KVS identifier를 사용합니다.

## 다음 확장

MBC/SBS 공식 스트림 갱신, CBS 외 편성 데이터, 매일 편성을 갱신하는 알림 서버, CarPlay, 기기 간 재생 이어듣기, 선택 가능한 청취 기록.

## 검증 자료

[검증 기록](docs/VALIDATION.md), [시뮬레이터 화면](docs/preview.html), [디자인 조사](.lazyweb/quick-references/korean-radio-2026-10-06/report.html).

Apple 자료: [Liquid Glass](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views), [Widget backgrounds](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background).

## CBS 및 뉴스·시사 분류 · 2026-10-06

CBS 표준FM(98.1)과 CBS 음악FM(93.9)을 공식 스트림으로 기본 목록에 포함합니다. CBS 표준FM·KBS 1라디오·YTN 등은 뉴스·시사, CBS 음악FM은 음악으로 분류합니다. 전체/뉴스·시사/음악/클래식 필터를 iPhone·Watch·TV에 적용했고, iPhone 홈에 뉴스 방송 바로가기를 추가했습니다. 뉴스·시사 채널에서도 시간대에 따라 음악·교양 프로그램이 방송됩니다. 목록 갱신 후에도 CBS 기본 채널을 유지하고 알려진 CBS/KBS 이름 중복을 정리합니다.

## 백그라운드 재생과 플레이어 개선 · 2026-10-06

실제 앱 Info.plist의 `UIBackgroundModes`에 `audio`를 명시합니다. `.playback` 오디오 세션과 함께 홈 화면·다른 앱·화면 잠금 상태에서 재생을 지원하며, 전화 등 오디오 중단 후 시스템이 재개를 허용할 때만 다시 재생합니다. 이어폰 연결이 끊어지면 일시정지합니다.

플레이어는 작은 아트워크, 방송국 색의 은은한 배경, 현재 프로그램 카드와 큰 재생 버튼으로 정리했습니다. 연결 진단은 더 보기 메뉴에 있습니다.

평양 FM, Vorbis 스트림, TV 항목을 제외합니다. 기본 목록의 만료 주소·접근 거부·인증서 오류 등 연결 실패 항목도 정리했고, 새 목록을 가져올 때 서버와 HLS 하위 리소스를 검사하여 실패 항목을 표시하지 않습니다. 오래된 목록 캐시는 새 검증 캐시로 교체됩니다. 방송 서버 상태는 시간과 네트워크에 따라 변할 수 있습니다.

## Podcasts 스타일 플레이어

전체 화면의 어두운 방송국 색 배경, 중앙 아트워크, 현재 방송 정보, 큰 흰색 재생 컨트롤을 사용합니다. 아래쪽 볼륨, AirPlay, 편성표, 방송국 목록과 취침 타이머를 제공합니다. 위쪽 손잡이를 누르거나 표지를 아래로 드래그하면 닫습니다. 실시간 라디오의 이전·다음 버튼은 방송국을 이동합니다.

Dynamic Island는 iOS 기본 Now Playing 표시를 사용합니다. 중복되는 별도 라디오 Live Activity는 생성하지 않으며, 이전 버전의 남은 활동은 실행 시 종료합니다.

### 채널별 편성표

보관함 → 오늘의 편성표에서 라디오 채널을 선택합니다. CBS는 공식 일일 편성, KBS는 공식 일일 편성(전날 방송일의 새벽 일정 포함), MBC는 공식 요일별 정규 편성을 표시합니다. SBS·YTN 및 기타 채널은 선택한 채널의 공식 사이트에서 확인합니다. 특별 편성은 공식 사이트를 우선 확인하세요. 번호형 빠른 재생은 제거했고 제어센터는 최근 방송을 재생합니다.

### 날씨와 지금·다음 방송

홈의 날씨 카드에서 지역(기본 서울), 현재 기온, 최고/최저, 오늘 강수확률을 확인합니다. 카드를 누르면 생성된 낮·밤 하늘 배경과 반투명 카드로 구성한 전체 화면 날씨가 열립니다. 시간별·10일 예보, 체감온도, 습도, 풍속·풍향·돌풍, 자외선, 일출·일몰, 예상 강수량, 기압, 가시거리와 구름량을 확인할 수 있습니다. 상단 지역 버튼 또는 설정 → 날씨와 지역에서 지역을 바꾸며, 전체 화면을 아래로 당겨 새로고침합니다. 현재 위치 사용은 선택 사항이며 사용 중 위치 권한만 요청하고 약 2km 격자로 좌표를 반올림합니다. 자동 위치 추적은 하지 않습니다.

날씨는 Open-Meteo 예보를 사용하며 출처 링크를 표시합니다. API 키 없이 동작하는 현재 개인 개발용 구현입니다. 상업 배포 전 Open-Meteo 이용 플랜을 확인해야 합니다. 예보는 30분 캐시, 하루가 지난 캐시는 숨기며 연결 실패 시 저장된 예보임을 안내합니다.

홈과 플레이어에는 공식 편성표에 기반한 지금·다음 방송을 표시합니다. 지원 채널/특별 편성의 제한은 채널별 편성표와 같습니다. 홈 화면 위젯 추가 → 온에어 → ‘날씨와 라디오’를 선택하면 작은/중간 위젯에서 앱의 지역과 선택한 방송을 확인하고 재생할 수 있습니다. 위젯 갱신 시점은 iOS가 조정할 수 있습니다.

### 심플 리퀴드 글래스 디자인

2026-10-07 사용자 참고 이미지에 맞춰 iPhone 홈·방송국·보관함을 목록 중심으로 정리했습니다. 밝은 파스텔 배경, 작은 방송국 아트워크, 오렌지 강조색을 사용하고 플레이어는 중앙 아트워크와 유리 재생 버튼에 집중합니다. 다크 모드 설정도 따릅니다. 날씨, 지금·다음 편성, 즐겨찾기, 타이머, AirPlay와 기상 알람은 기존 동선을 유지합니다.

### 미니멀 홈과 미니 라디오 위젯

홈은 날씨 한 줄, 현재 방송, 즐겨찾기로 구성합니다. 편성표·최근 기록 등은 기존 방송국/보관함 흐름에서 확인합니다. 홈과 보관함의 즐겨찾기 행을 길게 눌러 끌어서 순서를 바꾸며, VoiceOver의 위로/아래로 이동 동작도 지원합니다. 이 순서는 기기 내에서 저장되고 위젯에도 반영됩니다.

플레이어는 연결 중·생방송·일시정지·연결 실패를 한 줄로 표시합니다. 실패 시 다시 시도 버튼을 표시합니다. 취침 타이머는 마지막 30초 동안 앱 오디오 음량을 서서히 낮춘 후 멈추며, 해제 또는 종료 후 원래 앱 음량으로 복원됩니다. 시스템 전체 음량은 변경하지 않습니다.

홈 화면 위젯 추가 → 온에어 → **미니 라디오**에서 방송국과 재생 버튼만 표시하는 작은 위젯을 추가할 수 있습니다. 위젯 편집에서 최근 방송 또는 출근/퇴근/취침 프리셋을 선택합니다. 홈 방송 아트워크를 길게 누르면 탁상 라디오와 공유를 열 수 있습니다.

## Watch 사용 흐름 (2026-10-14)

좌우 스와이프로 채널 / 재생 / 설정을 이동합니다. 재생 화면에서는 디지털 크라운이 온에어 AVPlayer 재생 음량을, 채널 화면에서는 스크롤을 제어합니다. 평소 음량 UI는 숨기고 입력 시 오른쪽에 일시적인 바를 표시하며 마지막 입력 후 1.2초 뒤 숨깁니다. iPhone 제어 모드는 WatchConnectivity로 온에어 음량을 전달합니다. 시스템/이어폰 전체 음량과는 별개입니다. 재생 버튼에는 지원 기기에서 손 제스처 primary action을 연결했습니다(이 API 자체는 27 신규 기능이 아닙니다).

watchOS 27: 설정 → 즐겨찾기 순서에서 채널을 길게 눌러 이동합니다. 변경된 순서는 워치의 공유 저장소에 저장되며 채널 목록과 이전/다음 재생에 반영됩니다. VoiceOver 위로/아래로 이동 동작도 제공합니다. iPhone으로 순서 동기화는 구현하지 않았습니다.

검증: 42mm watchOS 27 및 46mm 워치 시뮬레이터 화면 확인, 순서 변경의 앞/뒤 이동·복수 선택·잘못된 대상 보존 단위 테스트 통과, 실제 Watch 설치 및 실행 확인. 물리 크라운·손 제스처·드래그의 실제 기기 입력과 청취는 별도 확인이 필요합니다.

## AirPlay와 크라운 표시

재생 화면의 기본 focus effect 및 scroll indicator를 숨겨 흰색 음량 HUD와 중복되지 않도록 설정했습니다. 워치 AirPlay 버튼은 출력 시트를 열며, iPhone에서 온에어를 열어 연결한 뒤 “iPhone에서 AirPlay 선택”을 누르면 현재 방송을 iPhone에서 재생하고 iPhone에 AVRoutePickerView 화면을 표시합니다. 사용자가 iPhone의 시스템 AirPlay 버튼을 눌러 실제 기기를 선택합니다. iPhone의 재생 응답을 확인한 뒤 워치 단독 재생을 멈추고 iPhone 제어로 전환합니다. 워치 단독 AirPlay 송출이나 외부 스피커 실재생은 검증하지 않았습니다.

## 현재 출력 표시

재생 화면 하단에는 AVAudioSession.currentRoute.outputs의 실제 기기 이름과 출력 유형 아이콘을 표시합니다. 오디오 경로 변경 알림에 맞춰 갱신하며 iPhone의 출력 정보는 ListeningSnapshot.audioOutput으로 워치에 전달합니다. 기존 스냅샷은 이 필드가 없어도 읽을 수 있습니다. iPhone 연결이 끊기면 이전 출력 이름 대신 연결 끊김을 표시합니다. 워치 제어 센터의 출력 선택(측면 버튼 → 오디오 출력)은 iPhone 화면 없이 이용할 수 있습니다. 앱은 제어 센터를 직접 여는 공개 API를 사용하지 않으며 안내와 시스템 재생 제어 진입을 제공합니다.

## 크라운 기본 표시 제거 수정

SwiftUI digitalCrownRotation의 기본 초록색 표시가 실기기에 남는 보고에 따라, 재생 화면의 해당 modifier와 focusable 입력 경로를 제거했습니다. 공개 WatchKit WKCrownSequencer로 회전 이벤트를 받아 임시 음량 HUD를 갱신합니다. 페이지·시트·앱 활성 상태 변경 시 이전 delegate와 focus를 복구하고 callback을 해제합니다. 시뮬레이터에서 sequencer 연결 및 delegate → 음량 변경 → HUD 자동 숨김 시나리오(CROWN_HUD_FLOW_PASS)를 확인했습니다. 물리 크라운 회전 중 실제 화면의 표시 여부는 사용자 기기에서 추가 확인이 필요합니다.

## 기기 설치 인증서 자동 갱신 (LaunchAgent)

무료 Apple 개발자 계정의 7일 인증서 만료 제한을 해결하기 위해 백그라운드 자동 갱신 데몬이 설정되어 있습니다.

- **동작 방식**: Mac의 `launchd`가 6시간마다 백그라운드에서 실행되며, 마지막 갱신 후 3일(72시간)이 경과하고 iPhone이 같은 네트워크/케이블에 연결되어 있으면 자동으로 빌드(`xcodebuild -allowProvisioningUpdates`) 및 재설치(`xcrun devicectl`)하여 7일 유효기간을 연장합니다.
- **실행 스크립트**: [`scripts/auto_renew.sh`](scripts/auto_renew.sh)
- **수동 즉시 갱신**: `./scripts/auto_renew.sh --force`
- **스케줄러 설정**: `~/Library/LaunchAgents/kr.davidkang.onair.autorenew.plist`
- **로그 확인**: `tail -f ~/Library/Logs/OnAirAutoRenew.log`

