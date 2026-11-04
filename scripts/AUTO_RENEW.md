# 온에어 자동 서명 갱신

LaunchAgent `kr.davidkang.onair.autorenew`는 로그인 후 6시간마다 scripts/auto_renew.sh를 실행합니다. 앱에 포함된 프로비저닝 프로파일 만료가 3일 이내이면 연결된 아이폰을 확인하고 clean build, 자동 서명, 재설치를 수행합니다. 새 프로파일 유효기간이 2일 미만이면 성공으로 기록하지 않습니다. 앱 데이터는 삭제하지 않습니다.

조건: 맥 로그인 및 실행 상태, Xcode 계정 인증과 키체인 사용 가능, Apple 서버 인터넷 연결, 신뢰된 아이폰 USB 또는 Xcode 무선 연결. 아이폰이 잠겨 설치할 수 없거나 계정 재인증이 필요하면 다음 실행에서 재시도합니다. iPhone 단독으로 서명을 연장할 수 없습니다.

로그: ~/Library/Logs/OnAirAutoRenew.log
수동 실행: bash /Users/davidkang/onair/scripts/auto_renew.sh --force

빌드 성공과 만료일 연장, 설치 성공은 따로 확인합니다. 유효기간 판단은 설치 시각이 아닌 embedded.mobileprovision의 ExpirationDate를 사용합니다.
