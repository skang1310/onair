# CBS 알람 자동화와 Siri

앱을 한 번 실행한 뒤 Siri에 “온에어에서 CBS 라디오 틀어줘”라고 말하세요. 기본 방송은 CBS 표준FM입니다. “온에어에서 CBS 음악FM 틀어줘”는 음악FM을 재생합니다.

아이폰 단축어 앱 → 자동화 → + → 알람 → 중단될 때 → 원하는 알람(또는 기상) → 즉시 실행 → 새로운 빈 자동화 → 동작 추가 → 온에어의 “CBS 라디오 듣기” → CBS 표준FM 선택 → 완료.

이 자동화는 울리는 알람을 중단했을 때 실행됩니다. 시계 앱에서 알람 스위치를 끄는 동작과는 다릅니다. 자동화 등록은 앱이 대신 수행하지 않습니다.

AudioPlaybackIntent와 AppShortcutsProvider를 사용하며 앱 화면을 열지 않고 앱 프로세스에서 재생합니다. 실제 재생 시작을 기다리고 연결 오류를 단축어에 전달합니다. iOS 27 SDK 빌드 검증; 실기기 Siri 음성 인식 및 알람 트리거 실사용은 별도 확인이 필요합니다.

https://support.apple.com/ko-kr/guide/shortcuts/apd932ff833f/ios
https://developer.apple.com/documentation/appintents/audioplaybackintent
