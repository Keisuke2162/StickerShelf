#!/bin/bash
# ビルド + 全テスト + Swift 6 警告ゼロを判定する。
# Xcode の DEVELOPER_DIR を自動選択し、利用可能な iPhone シミュレータを選んで実行する。
# 成功時のみ exit 0。警告が1件でもあれば exit 1。
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -z "${DEVELOPER_DIR:-}" ]; then
  if [ -d /Applications/Xcode-27.0.0.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode-27.0.0.app/Contents/Developer
  elif [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  else
    echo "Xcode が見つかりません" >&2
    exit 1
  fi
fi

XCRUN=/usr/bin/xcrun

PROJECT="$ROOT/StickerShelf.xcodeproj"
SCHEME="StickerShelf"

# 利用可能な iPhone シミュレータを自動選択（最新 iOS、名前が「iPhone 」で始まるもの）
DEVICE_LINE="$($XCRUN simctl list devices available 2>/dev/null \
  | awk '/^-- iOS [0-9]/ {ios=$0} /\(.*\) \(Shutdown\)/ || /\(.*\) \(Booted\)/ { if (ios != "" && $0 ~ /iPhone/) print ios "\t" $0 }' \
  | grep -v 'unavailable' \
  | tail -1)"

if [ -z "$DEVICE_LINE" ]; then
  echo "利用可能な iPhone シミュレータが見つかりません" >&2
  exit 1
fi

DEVICE_UDID="$(echo "$DEVICE_LINE" | sed -n 's/.*(\([0-9A-F-]*\)).*/\1/p')"
DEVICE_NAME="$(echo "$DEVICE_LINE" | sed -n 's/.*\t[ ]*\(.*\) ([0-9A-F-]*).*/\1/p')"
IOS_VER="$(echo "$DEVICE_LINE" | sed -n 's/.*-- iOS \([^ ]*\) --.*/\1/p')"

echo "==> Simulator: ${DEVICE_NAME} (iOS ${IOS_VER}) ${DEVICE_UDID}"

LOG="$ROOT/.verify.log"
rm -f "$LOG"
rm -rf "$ROOT/.verify.xcresult"

echo "==> xcodebuild test"
$XCRUN xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$DEVICE_UDID" \
  -configuration Debug \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  -resultBundlePath "$ROOT/.verify.xcresult" \
  test > "$LOG" 2>&1
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  echo "==> ビルド/テスト失敗 (exit=$STATUS)" >&2
  tail -120 "$LOG" >&2
  exit 1
fi

# "warning:" が含まれていたら失敗
WARN_COUNT=$(grep -E ": warning: " "$LOG" | wc -l | tr -d ' ')
if [ "$WARN_COUNT" -gt 0 ]; then
  echo "==> 警告が ${WARN_COUNT} 件検出されました" >&2
  grep -E ": warning: " "$LOG" | head -40 >&2
  exit 1
fi

# テストが実際に実行されたか確認
if ! grep -q "\*\* TEST SUCCEEDED \*\*" "$LOG"; then
  echo "==> テストが完了していません" >&2
  tail -60 "$LOG" >&2
  exit 1
fi

PASSED_COUNT=$(grep -cE "Test case '.*' passed" "$LOG")
echo "==> App スキーム: ビルド成功・テスト成功 (${PASSED_COUNT} tests)・警告ゼロ"

# ShelfKit パッケージの全テストを実行（Swift Testing）
PKG_LOG="$ROOT/.verify-pkg.log"
rm -f "$PKG_LOG"
echo "==> ShelfKit swift test"
pushd "$ROOT/Packages/ShelfKit" > /dev/null
$XCRUN swift test --no-parallel > "$PKG_LOG" 2>&1
PKG_STATUS=$?
popd > /dev/null

if [ "$PKG_STATUS" -ne 0 ]; then
  echo "==> パッケージテスト失敗 (exit=$PKG_STATUS)" >&2
  tail -120 "$PKG_LOG" >&2
  exit 1
fi

PKG_WARN=$(grep -E ": warning: " "$PKG_LOG" | wc -l | tr -d ' ')
if [ "$PKG_WARN" -gt 0 ]; then
  echo "==> パッケージに警告が ${PKG_WARN} 件検出されました" >&2
  grep -E ": warning: " "$PKG_LOG" | head -40 >&2
  exit 1
fi

echo "==> OK: App + ShelfKit どちらもビルド・テスト成功・警告ゼロ"
exit 0
