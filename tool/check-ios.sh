#!/usr/bin/env bash
# Local equivalent of the macOS CI jobs (`ios`, `ios-cocoapods`). macOS + Xcode only.
# Usage: tool/check-ios.sh [spm|cocoapods|all]   (default: spm)
set -euo pipefail

mode="${1:-spm}"
root="$(cd "$(dirname "$0")/.." && pwd)"

boot_simulator() {
  udid=$(xcrun simctl list devices available --json \
    | jq -r '[.devices | to_entries[] | select(.key | test("iOS")) | .value[]
              | select(.name | startswith("iPhone"))] | last | .udid')
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  echo "$udid"
}

xctest() { # $1 = udid
  (cd ios && xcodebuild test \
    -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
    -destination "id=$1" -only-testing:RunnerTests \
    -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO)
}

check_spm() {
  cd "$root/example"
  flutter config --enable-swift-package-manager >/dev/null
  flutter build ios --simulator --debug
  test ! -e ios/Podfile
  grep -q advanced_webview ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift
  find build/ios/iphonesimulator/Runner.app -path '*advanced_webview*' -name PrivacyInfo.xcprivacy | grep .
  local udid
  udid=$(boot_simulator)
  flutter test integration_test -d "$udid"
  flutter build ios --config-only --simulator --debug
  xctest "$udid"
}

# Runs in a throw-away worktree so the project.pbxproj edit never touches your checkout.
check_cocoapods() {
  local tmp
  tmp=$(mktemp -d)
  git -C "$root" worktree add --detach "$tmp/wt" HEAD >/dev/null
  trap 'git -C "$root" worktree remove --force "$tmp/wt"; rm -rf "$tmp"' RETURN
  # Include uncommitted changes of tracked files.
  git -C "$root" diff HEAD | git -C "$tmp/wt" apply --allow-empty
  cd "$tmp/wt"
  flutter pub get >/dev/null
  flutter config --no-enable-swift-package-manager >/dev/null
  # See the ios-cocoapods job in .github/workflows/ci.yaml for why this reference is removed.
  sed -i '' '/\/\* advanced_webview \*\//d' example/ios/Runner.xcodeproj/project.pbxproj
  ! grep -q advanced_webview example/ios/Runner.xcodeproj/project.pbxproj
  cd example
  flutter build ios --simulator --debug
  grep -q 'advanced_webview (from' ios/Podfile.lock
  find build/ios/iphonesimulator/Runner.app -path '*advanced_webview*' -name PrivacyInfo.xcprivacy | grep .
  xctest "$(boot_simulator)"
  flutter config --enable-swift-package-manager >/dev/null
}

case "$mode" in
  spm) check_spm ;;
  cocoapods) check_cocoapods ;;
  all) check_spm; check_cocoapods ;;
  *) echo "usage: $0 [spm|cocoapods|all]" >&2; exit 2 ;;
esac
