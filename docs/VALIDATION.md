# 검증 기록 · 2026-10-06

## 빌드

Xcode 27.0 / 27A266a. Swift 6 strict concurrency. 최소 OS 26.0.

- iOS 27 Simulator: OnAir 및 포함된 iPhone 위젯/Live Activity extension 빌드 성공.
- watchOS 27 Simulator: OnAirWatch 및 Watch WidgetKit extension 빌드 성공.
- tvOS 27 Simulator: OnAirTV 빌드 성공.
- TV에서 AppIntents 메타데이터 추출 생략 경고가 있습니다. TV 타깃에 AppIntents 기능을 넣지 않았으므로 빌드 실패가 아닙니다.

## 자동 테스트

OnAirTests / CatalogTests: 4개 통과, 0 실패.

1. 실제 번들 목록 디코딩과 KBS Cool FM 포함 확인.
2. 파일 URL 등 스트림 이외 스킴 거부.
3. 특수문자 포함 위젯 딥링크 ID 왕복.
4. 서명된 스트림 URL 및 즐겨찾기의 Codable 보존.

Unit 테스트 결과는 UI 테스트나 실기기 검증을 의미하지 않습니다.

## 실제 실행

- iPhone 18 Pro / iOS 27: 시뮬레이터 설치 및 홈·재생 화면 확인.
- Apple Watch Series 12 / watchOS 27: 시뮬레이터 설치·실행 및 방송 목록/재생 화면 확인.
- Apple TV 4K / tvOS 27: 시뮬레이터 설치·실행 및 헤더/방송국 카드/포커스 화면 확인.
- KBS Cool FM 최신 공식 HLS URL: HTTP 200, `#EXTM3U` 확인.
- iPhone에서 AVPlayer `.playing` 상태 확인. `playback-observation.json`의 `isPlaying`은 플레이어의 timeControlStatus에서 저장한 값입니다. 청취 음질을 직접 평가하거나 실물 스피커 출력을 확인한 것은 아닙니다.
- 스크린샷은 실제 시뮬레이터 캡처. iPhone 재생 화면은 DEBUG 실행 인자로 KBS 방송을 선택했습니다. 시스템 URL 열기 확인창으로 가려졌던 테스트 캡처는 시뮬레이터 재시작 후 다시 촬영했습니다.

HTTP 테스트 결과: `stream-probes.json`. 공개 디렉터리의 만료된 KBS 주소는 403이었으나 공식 주소 갱신으로 200이 되었습니다. 일부 MBC/SBS는 여전히 400/403. 모든 방송국을 재생 점검하지 않았습니다. Listen.moe 기본 주소의 OGG 응답은 AVPlayer 호환성을 검증하지 않았습니다.

## 남은 검증

- 실제 iPhone/Watch/TV 설치와 청취, Watch 출력 경로 활성화 및 장시간 백그라운드 재생.
- AirPlay 실기기 전환, 헤드폰/전화/네트워크 끊김 이후 동작.
- 홈/잠금화면/Watch Smart Stack/complications 위젯 실제 추가 및 탭 동작.
- StandBy 실제 배치·야간 모드, Dynamic Island/Live Activity 실제 표시, Siri 단축어 실행.
- 앱/위젯 App Group 공유: 이 빌드는 코드 서명 없이 시뮬레이터에서 실행했으므로 실제 entitlement 기반 공유 컨테이너 동작은 검증하지 않았습니다. 실제 기기용 Signing/App Group 설정 필요.
- 접근성 큰 글자·VoiceOver·Reduce Transparency/Motion, 모든 화면 크기와 TV 리모컨 전체 동선.
- 기기 간 즐겨찾기/재생 동기화는 미구현. 위젯 내 직접 재생/정지 버튼도 미구현.

## API 근거

- Apple Liquid Glass: https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views
- Apple WidgetKit backgrounds: https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background
- 공개 방송 디렉터리: https://docs.radio-browser.info/
- KBS 최신 라디오 URL 응답: https://cfpwwwapi.kbs.co.kr/api/v1/landing/live/channel_code/25

Lazyweb 스킬을 읽고 연결된 도구를 조회했으나 MCP 도구가 노출되지 않았습니다. 공식 웹 자료로 대체했고, Lazyweb 스크린샷 검색 성공으로 표현하지 않았습니다. iOS 27 전용 신규 기능이라는 주장은 하지 않았습니다.

## 실물 iPhone 설치 시도 · 2026-10-06

iPhone 18 Pro의 연결을 확인했습니다. 로컬 개발 인증서의 OU에서 실제 서명 Team AXCMBMA992를 확인하여 project.yml에 설정했습니다. 기기용 xcodebuild는 Xcode의 `No Accounts` 및 온에어 bundle ID별 provisioning profile 부재로 실패했습니다. 실물 기기에 온에어를 설치하거나 실행하지 못했습니다. Xcode Settings → Accounts에서 개발 Apple 계정 로그인을 완료한 뒤 프로파일 생성과 기기 빌드·설치·실행을 다시 진행해야 합니다. 기존 다른 앱의 프로파일은 사용하지 않았습니다.

## Xcode 오류 수정 및 iPhone 설치 · 2026-10-06

- 공유 RadioPlayer의 iOS/tvOS `setActive(true, options:)` 호출에 붙어 있던 미지원 완료 콜백을 제거하고 throwing 동기 API를 사용하도록 수정했습니다. Watch 전용 `activate(options:completionHandler:)` 경로는 유지했습니다. SDK 헤더 선언과 실제 컴파일로 확인했습니다.
- 기본 OnAir 스킴은 iPhone 앱 및 iPhone 위젯만 패키징합니다. Watch 앱/위젯 프로파일 미등록이 iPhone 설치를 막지 않도록 Watch 포함 패키지는 별도의 OnAirWithWatch 타깃/스킴으로 분리했습니다. OnAirWatch와 OnAirTV 타깃은 유지했습니다.
- iPhone/iPad 화면 방향 Info.plist 설정을 추가해 기기 빌드의 interface orientation 경고를 해결했습니다.
- 실제 iPhone용 서명 빌드: BUILD SUCCEEDED, 오류/경고 없음. iPhone에 온에어 앱 및 iPhone WidgetKit extension 설치 성공.
- OnAirTests 4개 통과, 실패 0. Watch/TV 시뮬레이터 빌드 성공. TV의 AppIntents 메타데이터 생략 경고는 해당 기능 미사용으로 인한 경고입니다.
- 실제 iPhone 전경 실행은 기기가 잠겨 있어 `Locked` 오류로 거부되었습니다. 설치 성공과 실행 완료를 구분합니다. 사용자 잠금 해제 후 실행 재시도 필요.
- Watch 포함 실물 배포에는 Watch 앱과 Watch 위젯의 개발 프로파일이 여전히 필요합니다. 이 두 타깃의 서명 프로파일을 생성했다고 주장하지 않습니다.

## 하단 재생 바 겹침 수정 · 2026-10-06

TabView 외부 safeAreaInset을 제거하고 iOS 26부터 지원되는 tabViewBottomAccessory(content:)로 미니 플레이어를 배치했습니다. 확장/inline placement에 맞춰 표시 정보를 조정하고 유리 배경은 시스템 렌더링을 사용합니다. 홈의 수동 110pt 하단 패딩은 32pt로 정리했습니다. 연결 중 ProgressView 및 취소 레이블, 일시정지 상태 문구, 현재 방송 파형 표시를 추가했습니다. 재생/연결 중인 동일 방송을 다시 누르면 스트림을 다시 요청하지 않고 전체 재생 화면을 엽니다.

- iOS 27 시뮬레이터 빌드 성공 및 실제 방송 재생 중 레이아웃 캡처 확인: docs/screenshots/iphone-mini-player-fixed.png. 재생 바와 탭 바가 별도 줄에 있고 겹치지 않습니다.
- 기기용 서명 빌드 성공: build/device/Build/Products/Debug-iphoneos/OnAir.app.
- 현재 물리 iPhone은 unavailable 상태이므로 이번 수정 버전은 실제 기기에 재설치하지 않았습니다.
- 수동 탭 전환, 가로 화면 및 큰 글자 크기의 추가 레이아웃 점검은 남아 있습니다. 이번 UI 변경에 대해 기존 unit 테스트를 재실행했다고 주장하지 않습니다.
- Lazyweb MCP 도구는 노출되지 않아 디자인 개선 스킬의 웹 fallback을 사용했습니다. Apple 탭 accessory 공식 문서와 사용자가 제공한 오류 화면으로 판단했습니다.

## CBS 및 뉴스·시사 카테고리 · 2026-10-06

- CBS 공식 홈페이지의 표준FM/음악FM HLS 주소를 확인하고 기본 방송 목록에 추가했습니다. CBS 표준FM·음악FM 및 YTN 주소 모두 HTTP 200과 HLS 응답을 확인했습니다: news-stream-probes.json.
- iPhone 뉴스·시사 전용 탭 및 홈 바로가기, Watch/TV 공통 분류 필터를 추가했습니다. CBS 음악FM 분류, 기본 CBS 유지, CBS/KBS 별칭 중복 정리를 포함해 unit 테스트 7개 통과, 실패 0.
- iPhone 시뮬레이터 및 기기용 서명 빌드, Watch/TV 시뮬레이터 빌드 모두 성공.
- iPhone 시뮬레이터에서 CBS 표준FM AVPlayer 재생 상태 확인: cbs-playback-observation.json. 실제 캡처 screenshots/iphone-news.png에서 뉴스 탭과 겹침 없는 재생 바를 확인했습니다. 직접 청취 음질 및 실물 스피커 출력은 평가하지 않았습니다.
- 현재 물리 iPhone 연결 unavailable: 이번 CBS 업데이트는 실물 기기에 설치하지 않았습니다.
- 공식 근거: https://www.cbs.co.kr/ 및 https://www.cbs.co.kr/radio, https://radio.ytn.co.kr/. 뉴스·시사는 24시간 뉴스 전용을 뜻하지 않습니다.

## 1–8번 확장 기능 · 2026-10-06

1. ConnectionHealth: 방송 주소 갱신 후 서버 응답과 HLS 내용을 소량 확인합니다. 목록 길게 누르기/재생 화면에서 직접 확인합니다. 응답 확인은 실제 청취 보장과 구분합니다. RadioPlayer는 2/5/10초 간격 최대 3회 재연결하며 정지/방송 변경 시 취소합니다. iOS/tvOS 오디오 세션 활성화는 메인 스레드 밖에서 처리합니다.
2. DeviceSync: 항목별 날짜/리비전과 삭제 기록 병합. iPhone–Watch WatchConnectivity, iPhone–TV iCloud KVS. 페어링된 iPhone 18 Pro Max/Watch Series 12 시뮬레이터에서 CBS 즐겨찾기 전달을 실제 확인했습니다: pair-phone-initial.json, pair-watch-initial.json. 실제 iCloud 기기 간 동기화는 미검증입니다.
3. CBS 공식 /schedule/radio/ajax 오늘 편성 데이터(표준FM/음악FM), 한국 시간 처리 및 저장한 프로그램의 시작 5분 전 알림. 앱 활성화 시 편성 갱신. 확인한 오늘 미래 방송만 예약하며 내일 편성을 임의 반복하지 않습니다. CBS 외 편성은 공식 링크로 대체합니다.
4. 실제 프로그램 제목 기준 종합 뉴스/경제/시사 토론/지역 뉴스 분류, 방송사 필터. 지역 방송국은 목록에 명시된 지역명으로 구분합니다. 확인된 프로그램이 없는 분류는 빈 상태로 설명합니다.
5. 출근/퇴근/취침 프리셋, 방송 및 종료 시간 수정, App Group 저장.
6. Watch 독립 재생/iPhone 제어 선택. 방송 변경, 재생/정지, 취침 타이머 및 상태 요청. 도달 가능 연결에서 명령을 보내며 10초 응답 안내와 이전 요청 응답 구분을 적용합니다. 시뮬레이터에서 Watch의 pause 명령이 iPhone에 수신되어 실제 재생 상태가 false가 된 것을 확인했습니다: pair-phone-paused.json. Watch 연결 전환/응답 지연과 실제 하드웨어 검증은 남아 있습니다.
7. AudioPlaybackIntent로 앱 프로세스 재생. 앱/위젯 양쪽에 intent를 포함합니다. 재생 중 방송과 오래된 위젯의 방송 ID가 다르면 정지 명령을 무시합니다. circular/rectangular 및 홈 위젯 버튼; inline은 링크. 프리셋 선택 설정 및 medium 즐겨찾기 재생.
8. 침대 옆 라디오 위젯: 어두운 기본 배경, 시계, 재생 버튼, 방송명, 실제 취침 종료 시각 카운트다운. StandBy에서 배경을 제거할 수 있는 기본 설정을 유지합니다. 시스템 배치/야간 적색 렌더링/장시간 실제 기기 검증은 남아 있습니다.

### 서명

기존 iPhone 개발 프로파일에 iCloud 권한이 없어 Cloud entitlement를 추가한 첫 실기기 빌드는 실패했습니다. Xcode 개발 계정도 없어서 프로파일 갱신은 불가능했습니다. 기본 OnAir/OnAirWithWatch는 기존 서명 설정을 유지하고, OnAirCloud/OnAirCloudWithWatch는 별도 entitlement와 CLOUD_SYNC를 사용합니다. 기본 OnAir의 서명 빌드는 성공했습니다. Cloud 실물 배포에는 개발 계정 로그인과 앱 ID/프로파일의 iCloud 권한 설정이 필요합니다. Watch 포함 실물 배포는 Watch 두 타깃 프로파일도 필요합니다. 물리 iPhone은 unavailable 상태여서 이 업데이트를 설치하지 않았습니다.

### 근거

- CBS 실제 편성표: https://www.cbs.co.kr/schedule?type=fm
- AudioPlaybackIntent 앱 프로세스 실행: https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities
- StandBy removable background 요구: https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background
- iCloud KVS entitlement: https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingiCloud.html

Lazyweb 도구가 노출되지 않아 스킬의 웹 fallback을 사용했습니다. 보고서: .lazyweb/design-improve/radio-features-2026-10-06/report.html.

기본 iPhone signed 빌드, Watch 포함 iOS/Watch simulator 패키지, OnAirCloud simulator 및 TV simulator 빌드는 최종 소스에서 성공했습니다. 기기별 실제 iCloud/AirPlay/StandBy 검증과 실물 설치는 이 빌드 성공과 구분합니다.

최종 단일 실행 검증: OnAirTests 18개, OnAirUITests 2개 모두 통과, 실패 0, TEST SUCCEEDED. 재연결 한도/취소, 삭제와 동시 변경 병합, 편성표 날짜·한국 시간·자정 처리, 뉴스 분류, 오래된 위젯의 다른 방송 정지 방지, 실제 CBS 경제 편성 필터와 알림 예약, 프리셋 수정 및 위젯 표시부의 재생·정지 intent 실행을 확인했습니다. UI 테스트의 위젯은 실제 위젯과 같은 표시부를 앱 안에서 렌더링한 미리보기이며, SpringBoard/Smart Stack/StandBy 시스템 배치 검증으로 확대해서 해석하지 않습니다. 결과 번들: build/features/Logs/Test/Test-OnAir-2026.10.06_09-59-15-+0900.xcresult.

## 2026-10-06 iPhone reinstall

Latest OnAir scheme signed device build completed successfully. Installed in place on connected iPhone 18 Pro (GreenGoblin) using devicectl, bundle `kr.davidkang.onair`. devicectl confirmed app installation and successful application launch. No uninstall was performed.

## 2026-10-06 background playback and player

- Root cause confirmed: previous signed iPhone app had no UIBackgroundModes entry. XcodeGen info properties now explicitly include audio for all iPhone schemes, and signed build plist confirms [audio].
- Playback session retains .playback/longFormAudio. Added system-authorized interruption resume and headphone-disconnect pause.
- Unit tests: 20 passed, zero failures (/tmp/onair-background-tests.log). Background capability and excluded catalog regression tests included.
- New UI test explicitly launches production bundle ID with parallel testing disabled; CBS audio advances by more than 10 seconds during a 15-second background check while Home Screen is foreground. Test case passed (/tmp/onair-background-ui-final.log). First attempts had XCTest target-alias/state issues and were unsuccessful; only final case is accepted as playback evidence.
- Signed iPhone build, Watch package simulator build, TV simulator build passed. Updated connected physical iPhone in place and launched successfully. Physical lock-screen endurance test remains unverified.
- Catalog: 47 unique eligible source entries probed; 34 received media bytes, 13 failed HTTP/certificate/protocol checks and removed. Separately excluded Pyongyang FM, TV and Vorbis/Ogg sources. Runtime refresh checks response content and HLS child resources before listing channels. HTTP probe is availability evidence, not a guarantee of decoder playback on every device.
- Source cache migrated to verified-station-cache-v2; removed entries filtered from restored snapshots/favorites and presets.
- Actual redesigned player capture: docs/screenshots/iphone-player-background.png.

Final UI test case completed with zero failures, but xcodebuild stalled after suite completion and the xcresult bundle did not finalize. Stopped the completed run; accept the test case log and manual screenshot as evidence, not a finalized xcresult or full TEST SUCCEEDED run. Final signed iPhone update also includes preset filtering and was reinstalled and launched.

## 2026-10-06 Apple Podcasts style player

User-provided Podcasts screenshot is the primary design reference. Replaced player sheet with full-screen player, artwork-tinted dark gradient, centered 14pt-radius artwork, thumbnail/program metadata, plain white playback controls, live indicator, sleep menu, favorites, system MPVolumeView on device, AirPlay, station list, and schedule. Artwork swipe-down and handle tap dismiss the player. Schedule sheet explicitly stays light to preserve its existing contrast. Simulator uses a real AVPlayer volume slider because MPVolumeView does not render the system volume slider there.

Signed iOS and simulator builds passed. Visually inspected actual simulator player with CBS playback and final paused presentation. Updated connected physical iPhone in place and launched. No new unit/UI test run for this presentation change; earlier background playback verification applies to unchanged playback lifecycle. Physical volume/AirPlay and gesture interaction have not been manually verified. Lazyweb tools unavailable; reference report records user screenshot plus Apple support materials.

## 2026-10-06 single playback island

Removed creation/update of the custom radio Live Activity. iOS system Now Playing remains the only playback presentation requested by OnAir. On RadioPlayer initialization, all Activity<RadioActivityAttributes>.activities from older versions are ended with immediate dismissal, including orphan activities across process launches. Other apps activities are unaffected. Signed iOS and simulator builds succeeded; updated and launched physical iPhone. Simulator Preferences screenshot records no additional custom radio indicator, but native Dynamic Island presentation on physical hardware was not visually verified.

## 2026-10-06 MBC/SBS, logos, recent listening
- CarPlay excluded as requested. Implemented in order: stream restoration, official logos, recent history.
- All five restored official APIs returned fresh HTTPS HLS URLs; playlist traversal returned HTTP 200 audio segment data (10,240 bytes each). See restored-stream-probes.json. Tokens remain in memory and are refreshed on each connection.
- MBC FM4U played in iPhone simulator; recent history appeared after actual playback, survived app relaunch, and paused relaunch preserved background preferences.
- Official logo assets bundled in app and both widget targets; MBC mini uses dark contrast, SBS uses official SBS play branding. Sources: station-logo-sources.json.
- Signed iOS build succeeded. 22 unit tests passed with TEST SUCCEEDED. Includes resolver mapping, URL host/protocol/token preservation, recent deduplication and history limit check.
- Final build installed in place and launched on connected iPhone 00008160-001430CC1021400A. Physical-device audible playback, Watch and TV runtime not tested in this update.

## 2026-10-07 CBS Siri and alarm Shortcuts
- Added CBS standard/music enum and dedicated AudioPlaybackIntent; default standard, waits for actual playback, fails if connection times out.
- Combined CBS Siri phrases with existing RadioShortcuts provider. Refreshes App Shortcut parameters at app startup.
- Xcode 27 / iPhoneOS27.0 signed build succeeded; exported extract.actionsdata contains PlayCBSRadioIntent and CBS phrases.
- Updated connected iPhone in place. Alarm personal automation must be configured on the iPhone; app cannot register this trigger itself. Siri spoken phrase and actual alarm trigger not tested. See CBS-SHORTCUTS.md.

## 2026-10-07 Dark mode
- Default system appearance with persistent system/light/dark picker under My Radio > Screen style.
- Semantic background, surface and ink colors for iOS, Watch and widget asset catalogs. Dark player remains immersive; schedule sheet honors selected appearance.
- iOS 27 signed device and simulator builds succeeded. Updated and launched connected physical iPhone. Simulator home dark screenshot visually verified; manual picker and physical appearance switching not exercised.
- No playback behavior changed; reversible visual change did not add unit tests. Screenshot: docs/screenshots/iphone-home-dark.png.

## 2026-10-07 Minimal tuner navigation
- Three native tabs: Radio, Stations, Library. News browser remains available inside Stations; news deep links select news filter. Favorites/settings/presets preserved under Library.
- Home replaces large decorative hero/cards with monochrome tuner display, frequency scale, warm paper surface and click-wheel interaction; orange identifies the tuning needle.
- Mapped Seoul FM reference frequencies for ten live stations. This is internet playback, not hardware FM reception. Streaming-only stations stay available in Stations.
- Dial uses wrapped angular deltas, bounded channel selection, selection feedback and plays only on drag end; previous/next buttons and VoiceOver adjustable action provided. Physical gesture/haptics not manually tested.
- Fixed color asset integral values to decimal component format so white surface does not render black.
- Signed iOS and simulator builds passed. Light/dark screenshots inspected. Final app installed in place on connected iPhone; production launch requested.
- Final physical launch was denied because iPhone was locked. Installation succeeded; user must unlock and open app. Simulator app launch succeeded.

## 2026-10-07 Radio extras and music recognition
- Added bounded accelerated tuning, optional generated click sound, numbered presets 1–5 with long press save, iOS 27 large/extra-large portrait panel, bedside clock, control widget, AlarmKit wake editor and stop-to-radio intent, current/next CBS official schedule line, and image share poster. No CarPlay.
- Recognition samples unencrypted AAC from broadcast HLS, generates a Shazam signature for the latest 12 seconds, displays matched title/artist and optional Apple Music link; automatic foreground check every 75 seconds plus manual lookup. No microphone. Clears stale station results; MP3/encrypted/fMP4 sampling unsupported.
- Actual broadcast extraction/signature generation verified for MBC FM4U, CBS Music, SBS Power and KBS Classic; durations recorded in song-audio-probes.txt.
- Real Shazam API request rejected with ShazamCore code 102 / HTTP 401: enable ShazamKit App Service for kr.davidkang.onair. Developer portal login handed to user. No actual song match confirmed.
- 28 unit tests passed (TEST SUCCEEDED). Bedside/share UI case passed; preset/wake-editor UI case passed after gesture fix. Test runners hung after suite completion and were terminated; individual passed suite logs retained in /tmp/onair-extras-ui.log and /tmp/onair-presets-fixed-ui.log.
- Signed iOS and simulator builds passed; tvOS and Watch simulator builds passed. Final signed update installed and launched on connected iPhone. Actual AlarmKit wake/background launch, system widget/control interactions, physical haptics/audio, Watch and TV runtime remain unverified. No alarm scheduled or share published during tests.

## 2026-10-07 AudD replacement
- Removed all ShazamKit imports, signature code and App ID capability flag. Replaced recognition with AudD standard HTTPS multipart POST. Latest 12 seconds exported as M4A; temporary files cleaned. No microphone.
- Public documented trial token enables manual recognition. Personal token stored in device-only unlocked Keychain, never embedded in sources/defaults/iCloud or logged. Personal account required for optional automatic mode; default disabled, migration disables prior automatic preference. Authentication/quota errors stop automatic requests. Shared commercial token needs a backend before public distribution.
- Actual provider results: official example Tears For Fears, stored CBS sample 라종민, SBS sample Ennio Morricone. Live iOS CBS Music stream produced Whitney Houston / I Will Always Love You (Ultimate Collection Edit) and displayed both in player. No fixture titles embedded in app. No manual comparison with audible broadcast performed.
- 33 unit tests passed, including binary multipart, match/no-match/auth/quota/malformed responses, safe music links and 14-second PCM to 12-second M4A export. Settings UI case passed after fixing test's Link element query. xcodebuild runners stalled after complete suites; only specific runner processes terminated. Passed suite logs retained /tmp/onair-audd-tests.log and /tmp/onair-audd-ui-fixed.log; xcresult packaging did not complete.
- Final signed device build passed and installed in place on connected iPhone. Actual provider end-to-end verified in iOS simulator. Keychain personal-token save with a live personal account and paid usage not tested or purchased.
- Final physical launch was denied because the iPhone was locked; installation succeeded. Unlock and open OnAir.

## 2026-10-07 Liquid Glass tab redesign and recognition removal
- iPhone home, station discovery and library rebuilt with native iOS 26+ Liquid Glass navigation, toolbar, grouped glass buttons and native bottom accessory. Violet/teal gradients, readable opaque content cards, adaptive station grid and native search. Light/dark system colors preserved. Decorative backgrounds drawn in SwiftUI, no generated raster asset needed.
- Removed rotary tuner, click sound asset/settings, music recognition UI, AudD client, audio sample/export helpers and recognition tests. Update startup removes only the former AudD personal Keychain item and obsolete feature preferences; no music-recognition network requests remain.
- Favorites, recent listening, numbered quick slots, routine presets/editors, schedule/reminders, AlarmKit editor, bedtime/landscape radio, share poster, Siri, widgets, background playback and system Now Playing preserved. Quick slots now in Library; screen mode/device/reminder/history settings in a sheet.
- Content bounds fix: hero decorative background clipped to actual layout size so it cannot bleed over the next section. System TabView reserves space for the mini-player/tab bar; no manual overlapping bottom overlay.
- 23 remaining unit tests passed. Both station-search/favorite and three-tab/settings UI cases passed on final run with TEST SUCCEEDED. The initial settings query used the wrong accessibility type for the Picker; corrected to a stable ID. Final result bundle: build/simulator/Logs/Test/Test-OnAir-2026.10.07_11-37-59-+0900.xcresult.
- Signed iOS build passed and installed in place on connected iPhone. tvOS and Watch simulator builds passed; their runtime behavior not tested in this redesign.
- Light home/station/library screenshots inspected. Hero background bounds and distinct mini-player/tab-bar layout visually confirmed.
- Dark home and refreshed glass player screenshots inspected; no song-recognition controls remain. Final physical update installed and launch succeeded.


## 빠른 재생 제거 · 채널별 편성표 · 2026-10-07

- 보관함의 번호형 빠른 재생, 위젯 번호 버튼, 공유 저장 슬롯을 제거했습니다. 제어센터는 최근 방송을 사용합니다. 기상 알람과 출근·퇴근·취침 루틴은 유지합니다.
- 편성표의 채널 선택과 개별 공식 링크, 채널별 프로그램 목록을 구현했습니다. CBS 공식 일일 응답, KBS 공식 weekly API(전날~오늘 방송일), MBC 공식 Schedule/schedulelist 요일별 정규 편성을 사용합니다. SBS·YTN·기타 채널은 공식 사이트 연결로 안내합니다.
- KBS의 24시 이후 방송 시간을 실제 다음 날짜로 변환하고 오늘과 겹치는 구간만 남깁니다. MBC는 한국 시간의 요일로 필터링하며 특별 편성은 별도로 확인하도록 안내합니다. 방송사 일부 연결 실패 시 다른 방송사 데이터를 유지하고 오늘 캐시를 표시합니다.
- OnAirTests 24개, 실패 0. 채널/요일/자정 경계 파서 테스트 2개 포함. 홈·방송국·보관함/설정 및 즐겨찾기 UI 테스트 2개 통과. 채널 선택 테스트의 홈 배경까지 검색하는 assertion을 선택 채널 헤더로 한정한 뒤 재실행 통과(1개, 실패 0).
- 최초 UI 실행은 기존 assertion 1개 실패 후 suite가 종료됐으나 xcodebuild 보고서 생성이 멈춰 해당 프로세스를 종료했습니다. 재실행도 XCTest suite 종료 후 보고서 생성이 완료되지 않아 해당 xcodebuild 프로세스를 종료했습니다. XCTest suite 통과 로그와 실행 화면으로 검증했고, 전체 test 명령의 TEST SUCCEEDED는 확인하지 못했습니다.
- iOS Simulator, iPhone 서명 빌드, watchOS/tvOS Simulator BUILD SUCCEEDED. 최종 iPhone 업데이트 설치 성공(bundleID kr.davidkang.onair). 전경 실행은 Locked 오류로 차단됐습니다.
- 실제 MBC 오늘 편성이 표시되는 시뮬레이터 화면을 docs/screenshots/iphone-channel-schedule.png에 저장하고 확인했습니다. 별도의 실물 Watch/TV 설치는 수행하지 않았습니다.
- 상세 로그: /tmp/onair-channel-tests.log, /tmp/onair-channel-ui-retest.log, /tmp/onair-channel-device-final.log, /tmp/onair-channel-tv.log, /tmp/onair-channel-watch.log.


## 날씨 · 지금/다음 방송 · 날씨 라디오 위젯 · 2026-10-07

- 홈의 날씨 카드와 날씨/지역 설정을 추가했습니다. 기본 서울, 국내 16개 도시 또는 사용자가 직접 요청한 현재 위치를 지원합니다. 사용 중 위치 권한만 선언하고 현재 위치 좌표를 0.02도 격자로 반올림해 예보 요청과 공유 저장에 사용합니다. 지속적인 위치 추적은 하지 않습니다.
- Open-Meteo Forecast API의 실제 서울 응답(current/daily, unixtime, Asia/Seoul)을 확인했습니다. 기온/최고/최저/일일 강수확률/날씨 코드를 파싱하고 날짜·배열·강수확률·예보 시각을 검증합니다. 날짜가 지난 캐시는 표시하지 않고 네트워크 실패와 오래된 예보를 안내합니다. API 키 없이 동작하며 상업 배포 플랜 확인은 README에 기록했습니다.
- 홈과 플레이어에 공식 편성표 기반 지금·다음 방송을 표시합니다. 시작/종료 경계와 채널 분리 로직을 테스트했습니다. 위젯용 편성표는 앱 그룹으로 공유합니다.
- ‘날씨와 라디오’ WidgetKit 위젯을 추가했습니다(systemSmall/systemMedium). 지역/예보 캐시를 앱과 공유하고 타임라인에 프로그램 전환 시각을 포함합니다. 선택 방송 재생/정지는 기존 AudioPlaybackIntent를 사용합니다. 앱으로 돌아오는 링크는 날씨/지역 설정을 엽니다.
- OnAirTests 28개 + WeatherRadioFlowTests 1개 통과, 실패 0. /tmp/onair-weather-tests.log의 TEST SUCCEEDED 확인. 지역 직접 변경 시 위치 권한을 요청하지 않는 동선을 검증했습니다. 실제 위치 권한 허용/거부 및 GPS 응답은 실물 기기에서 미검증입니다.
- 최종 iOS Simulator 및 iPhone 서명 빌드 BUILD SUCCEEDED. 공유 소스 변경 후 Watch/TV Simulator 빌드도 성공했습니다. 위치 관련 SDK 사용의 컴파일 오류는 없었습니다.
- iPhone 최종 업데이트 설치 성공: bundleID kr.davidkang.onair. 전경 실행은 기기 잠금으로 Locked 오류. 실제 기기의 날씨 화면/위젯 추가/위젯에서 재생은 검증하지 않았습니다.
- 시뮬레이터 홈에서 실제 부산 예보와 CBS 현재/다음 프로그램을 확인했습니다. 날씨 위젯의 작은/중간 렌더링은 앱 내 미리보기에서 확인했습니다. 시스템 위젯 호스트에서의 시각 검증과 구분합니다. 플레이어의 다음 방송 표시와 하단 버튼이 화면 안에 배치되는 것을 확인했습니다.
- 화면: docs/screenshots/iphone-weather-home.png, iphone-weather-widgets.png, iphone-weather-player.png. 디자인 보고서: .lazyweb/design-improve/weather-radio-2026-10-07/report.html. Lazyweb 도구 미노출로 Apple 위젯 가이드와 Open-Meteo 공식 자료를 참고했습니다.
- 로그: /tmp/onair-weather-tests.log, /tmp/onair-weather-device-final.log, /tmp/onair-weather-sim-final.log, /tmp/onair-weather-watch.log, /tmp/onair-weather-tv.log.


## 사용자 참고 이미지 기반 심플 리퀴드 글래스 · 2026-10-07

- 밝은 분홍/푸른 파스텔 배경과 오렌지 강조색, 간결한 방송국 행을 적용했습니다. 홈의 큰 색상 히어로는 아트워크/현재 채널/재생 버튼으로 분리했습니다. 방송국·보관함 그리드와 최근 방송 카드도 목록으로 정리했습니다.
- 전체 플레이어는 사용자 참고 이미지의 중앙 아트워크·파형·프로그램·재생 버튼 구도를 반영했습니다. 실제 SwiftUI Liquid Glass는 주요 재생 버튼과 시스템 탭·미니 플레이어에 사용합니다. 장식 파형은 실제 오디오 분석 데이터가 아니며 동작 줄이기를 존중합니다. 라이브 라디오에 탐색 가능한 가짜 재생 진행률을 추가하지 않았습니다.
- 현재/다음 방송, 날씨 지역 설정, 편성표, 즐겨찾기, 루틴, 기상 알람, AirPlay, 취침 타이머 동선을 유지했습니다. 플레이어의 강제 다크 설정을 제거해 앱의 라이트/다크 선택을 따릅니다.
- LiquidRadioFlowTests 4개 + WeatherRadioFlowTests 1개, XCTest suites에서 실패 0 확인. 플레이어 버튼/편성표 이동/닫기, 채널 선택, 세 탭과 설정, 검색/즐겨찾기, 위치 권한 없이 날씨 지역 변경을 검증했습니다. 테스트 종료 후 xcodebuild 보고서 생성이 멈춰 해당 프로세스(PID 62272)를 종료했습니다. TEST SUCCEEDED 전체 명령 종료는 확인하지 않았고 suite 통과 로그로 기록합니다.
- 이후 작은 아트워크 로고 여백, 재생 아이콘 색, 최근 방송 목록을 다듬고 최종 빌드 및 시각 검증했습니다. 최종 iOS Simulator/iPhone 서명 빌드 BUILD SUCCEEDED. 공유 강조색 변경 후 Watch/TV Simulator 빌드도 성공했습니다.
- 최종 iPhone 업데이트 설치 성공(bundleID kr.davidkang.onair), 최종 devicectl 전경 실행 성공(Launched application). 실제 기기 UI 픽셀 검증과 실물 Watch/TV 설치는 하지 않았습니다.
- 시뮬레이터에서 홈·방송국·보관함·밝은 플레이어·다크 플레이어 스크린샷을 저장하고 확인했습니다. 플레이어의 하단 버튼과 볼륨이 화면 안에 표시됩니다. 작은 화면/큰 글씨에서는 스크롤 가능한 구성을 유지하지만 별도 작은 기기·최대 글씨 검증은 하지 않았습니다.
- 화면: docs/screenshots/iphone-simple-home.png, iphone-simple-stations.png, iphone-simple-library.png, iphone-simple-player.png, iphone-simple-player-dark.png.
- 디자인 보고서: .lazyweb/design-improve/simple-radio-2026-10-07/report.html. 사용자 첨부 참고 이미지 사본을 references/user-reference.png에 보관했습니다. Lazyweb 도구 미노출로 첨부 이미지와 Apple 공식 Liquid Glass 자료를 사용했습니다.
- 로그: /tmp/onair-simple-tests.log, /tmp/onair-simple-sim-polish.log, /tmp/onair-simple-device-polish.log, /tmp/onair-simple-watch.log, /tmp/onair-simple-tv.log.


## 플레이어 파형 제거 · 2026-10-07

사용자 요청에 따라 아트워크 아래 RadioWaveform 표시와 미사용 컴포넌트를 제거했습니다. iOS Simulator 및 iPhone 서명 빌드 성공. iPhone 업데이트 설치 성공. 시뮬레이터 플레이어 화면에서 파형 제거와 컨트롤 배치를 확인하고 iphone-simple-player.png를 갱신했습니다. 낮은 영향의 UI 제거로 별도 자동 테스트를 추가하지 않았습니다. 로그: /tmp/onair-no-wave-device.log, /tmp/onair-no-wave-sim.log.

## 2026-10-07 — Full-screen weather

- Home weather card and `onair://weather` open `WeatherDetailView` as a full-screen cover. Region selection remains a separate sheet inside it.
- Generated daytime and nighttime sky assets are bundled as `WeatherSkyDay` / `WeatherSkyNight` and selected from forecast `is_day`.
- Open-Meteo request expanded to 10 days / hourly forecasts and current humidity, apparent temperature, wind, gusts, pressure and cloud cover. UV, visibility and dew point use nearest hourly forecast. Precipitation is today's forecast total; wind uses m/s explicitly.
- Live API probe returned 10 daily entries and 240 hourly entries, with m/s wind units. Missing metrics display “정보 없음”. Summary-only cache snapshots remain decodable and refresh on next use.
- iOS Simulator, signed iPhone, watchOS Simulator and tvOS Simulator builds succeeded. Updated app installed in place on connected iPhone.
- iPhone app launch confirmed with `devicectl`. Final display refinement uses Korean weekday names and 24-hour hourly labels.
- First test run: 29 unit tests and 1 full-screen region-selection UI test passed with 0 failures. The xcodebuild process stalled after successful suite completion and was terminated; no command-level `TEST SUCCEEDED` claim is made for that run.
- Final UI rerun after Korean date-label refinement passed (1 test, 0 failures), including actual hourly forecast presence and scrolling to humidity/detail metrics. Screenshots attached in test result.
- Final UI test command completed normally with `TEST SUCCEEDED`. Saved weather header and metric screenshots under `docs/screenshots/iphone-weather-detail.png` and `iphone-weather-metrics.png`.

## 2026-10-07 — Minimal radio improvements 1–5

- Home simplified to one-line weather, current channel and favorites. Existing presets/schedules remain in library; bedside/share moved to artwork context menu.
- Playback status uses connecting/live/paused/failure, with retry only on failure. LIVE marker is shown only while playing.
- Sleep timer applies an AVPlayer gain fade over the final 30 seconds, restores gain on cancellation/end, and shows remaining time beside the moon button. Real locked-device audible fade still requires a timed listening check.
- Favorites support drag reorder and VoiceOver move actions; local ordering is preserved through favorite merges and shared with widgets. Ordering across different devices is intentionally local.
- Added small `OnAirMinimalRadio` widget with only station name and play/pause, reusing AudioPlaybackIntent and existing recent/preset configuration. Actual WidgetKit host interaction requires adding the widget on the phone.
- All 31 unit tests passed (0 failures), including fade bounds/cancellation and favorite ordering after snapshot merge. iOS, watchOS Simulator and tvOS Simulator builds passed.
- A UI test detected a missing weather-row hit area after simplification; `.contentShape(Rectangle())` was added so the entire 44-point row is tappable. UI test rerun covers this fix.
- Fixed weather full-screen UI flow passed on rerun (1 test, 0 failures). Updated app installed on iPhone; automatic launch was rejected because the physical device was locked.
- Saved final home screenshot with actual CBS playback state as `docs/screenshots/iphone-minimal-home.png`. UI suite succeeded; xcodebuild stalled after suite completion and was terminated without claiming command-level success.
