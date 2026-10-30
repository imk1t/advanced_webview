# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

- iOS: raise the minimum iOS version to 18.0.
- iOS: run `evaluateJavaScript` on the main thread; it could hang when called off it.
- Make `README.md` English and move the Japanese README to `README.ja.md`.
- Add MIT license, community health files, issue/PR templates and pub.dev metadata.
- Pin Flutter 3.47.8 with FVM (`.fvmrc`); CI uses the same version.
- Android: detach the WebView from its previous container when a controller is shown
  by a new `MobileWebView`, so re-attaching a controller does not fail.
- iOS: app-initiated loads (`loadUrl`, `loadHtmlString`, `reload`, `goBack`,
  `goForward`) no longer reach `onNavigationRequest`, matching Android.
- Add native unit tests (Robolectric on Android, XCTest on iOS) and run the integration
  tests on an Android emulator and an iOS simulator in CI.
- Lint and format native code in CI: ktlint for Kotlin and swift-format for Swift
  (Pigeon-generated files are excluded).
- iOS: support both Swift Package Manager and CocoaPods, and ship a privacy manifest
  (`PrivacyInfo.xcprivacy`) with either. CI builds the example app with each.
- Add AI agent configuration (`AGENTS.md`, APM with shared skills from `imk1t/apm-shared`).

## 0.0.1

- Initial scaffold: Pigeon-based platform contract, Android (Kotlin) and iOS (Swift)
  implementations, and an example app.
