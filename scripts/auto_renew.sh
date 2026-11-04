#!/bin/bash
# OnAir iOS App Provisioning / Certificate Auto-Renew Script
# Automatically rebuilds and reinstalls the app to renew the 7-day provisioning profile.

set -e

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH"

PROJECT_DIR="/Users/davidkang/onair"
DEVICE_ID="00008160-001430CC1021400A"
BUNDLE_ID="kr.davidkang.onair"
SCHEME="OnAir"
TIMESTAMP_FILE="$PROJECT_DIR/build/.last_renew_timestamp"
RENEW_INTERVAL_SECONDS=259200 # 3일 (7일 만료 전에 여유 있게 3일마다 갱신)
LOG_FILE="$HOME/Library/Logs/OnAirAutoRenew.log"

mkdir -p "$HOME/Library/Logs"
mkdir -p "$PROJECT_DIR/build"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

FORCE_RUN=false
if [ "$1" == "--force" ] || [ "$1" == "-f" ]; then
    FORCE_RUN=true
fi

log "==== 온에어 인증서 자동 갱신 검사 시작 ===="

# Use the embedded profile expiration, never the last successful build time.
APP_PATH="$PROJECT_DIR/build/device/Build/Products/Debug-iphoneos/OnAir.app"
profile_remaining() {
    security cms -D -i "$APP_PATH/embedded.mobileprovision" 2>/dev/null | /usr/bin/python3 -c 'import sys,plistlib,datetime; p=plistlib.loads(sys.stdin.buffer.read()); print(int((p["ExpirationDate"]-datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)).total_seconds()))'
}
if [ "$FORCE_RUN" = false ] && [ -f "$APP_PATH/embedded.mobileprovision" ]; then
    REMAINING=$(profile_remaining || echo 0)
    if [ "$REMAINING" -gt 259200 ]; then
        log "실제 서명 유효기간이 $((REMAINING / 3600))시간 남아 있습니다. 다음 검사에서 확인합니다."
        exit 0
    fi
fi

# 2. iPhone 기기 연결 상태 확인
log "iPhone 기기($DEVICE_ID) 연결 상태 확인 중..."
DEVICE_STATUS=$(xcrun devicectl list devices 2>&1 | grep "$DEVICE_ID" || true)

if [ -z "$DEVICE_STATUS" ]; then
    log "iPhone 기기($DEVICE_ID)가 감지되지 않았습니다. (동일 Wi-Fi 미연결 또는 기기 꺼짐)"
    log "다음 주기(6시간 후)에 다시 시도합니다."
    log "==== 검사 완료 ===="
    exit 0
fi

if ! echo "$DEVICE_STATUS" | grep -Eq "connected|available"; then
    log "기기가 오프라인 상태입니다. 다음 주기에 다시 시도합니다."
    log "==== 검사 완료 ===="
    exit 0
fi

log "기기 연결 확인됨: $DEVICE_STATUS"

# 3. Xcode 빌드 및 프로비저닝 프로파일 갱신
log "온에어 앱 빌드 및 프로파일 갱신 시작 (xcodebuild)..."
cd "$PROJECT_DIR"

if xcodebuild -project "$PROJECT_DIR/OnAir.xcodeproj" \
    -scheme "$SCHEME" \
    -destination "id=$DEVICE_ID" \
    -allowProvisioningUpdates \
    -derivedDataPath "$PROJECT_DIR/build/device" \
    clean build >> "$LOG_FILE" 2>&1; then
    log "xcodebuild 빌드 및 서명 성공!"
else
    log "ERROR: xcodebuild 빌드 실패. 로그를 확인하세요: $LOG_FILE"
    exit 1
fi

APP_PATH="$PROJECT_DIR/build/device/Build/Products/Debug-iphoneos/OnAir.app"
if [ ! -d "$APP_PATH" ]; then
    log "ERROR: 빌드 산출물 OnAir.app을 찾을 수 없습니다: $APP_PATH"
    exit 1
fi

REMAINING=$(profile_remaining || echo 0)
if [ "$REMAINING" -lt 172800 ]; then
    log "ERROR: 빌드는 완료됐지만 서명 만료일이 충분히 연장되지 않았습니다. Xcode 계정 인증을 확인해야 합니다."
    exit 1
fi

# 4. 기기에 앱 설치 (갱신 적용)
log "기기에 갱신된 앱 설치 중 (xcrun devicectl)..."
if xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" >> "$LOG_FILE" 2>&1; then
    log "앱 설치 및 인증서 갱신 완료!"
    date +%s > "$TIMESTAMP_FILE"
    
    # macOS 사용자 알림
    osascript -e 'display notification "온에어 앱 서명 갱신 및 재설치가 완료되었습니다." with title "온에어 자동 갱신"' 2>/dev/null || true
    log "==== 자동 갱신 성공 완료 ===="
else
    log "ERROR: devicectl 앱 설치 실패. 로그를 확인하세요: $LOG_FILE"
    exit 1
fi
