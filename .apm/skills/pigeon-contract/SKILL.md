---
name: pigeon-contract
description: Add or change a Dart <-> native API of advanced_webview via pigeons/messages.dart, regenerate the bindings, and update the Dart, Kotlin and Swift sides together. Use for any change that crosses the platform channel.
---

# Changing the platform contract

`pigeons/messages.dart` is the only definition of the Dart <-> native contract. Read
`AGENTS.md` and `ARCHITECTURE.md` first; they take precedence over this skill.

## Steps

1. Edit `pigeons/messages.dart`.
   - Every HostApi / FlutterApi method takes `int webViewId` first; keep the single
     `AdvancedWebViewHostApi` / FlutterApi pair.
   - Mark host methods `@async` when the native side must await (Kotlin `suspend`,
     Swift `async`).
   - Do not use field names that clash with Swift `NSObject` (`description`, `hash`, ...).
2. Regenerate: `dart run pigeon --input pigeons/messages.dart`. Never edit
   `messages.g.dart`, `Messages.g.kt` or `Messages.g.swift` by hand.
3. Implement both platforms with the same shape:
   - Android: `android/src/main/kotlin/dev/k1t/advanced_webview/WebViewHostApiImpl.kt`
     (and `AdvancedWebView.kt` for view behaviour).
   - iOS: `ios/advanced_webview/Sources/advanced_webview/WebViewHostApiImpl.swift`
     (and `AdvancedWebView.swift`).
   - Absorb platform differences natively so Dart sees one behaviour; document any
     unavoidable difference in dartdoc and `ARCHITECTURE.md`.
4. Expose it in Dart through `AdvancedWebViewController` (wrap calls with `_call` so they
   wait for creation and fail after `dispose()`); for native -> Dart events, route them
   through `WebViewEventDispatcher` by `webViewId`.
   - Native events the app may not want (scroll, long press) cost a channel message each, so
     gate them with a `hasXDelegate` flag in `CreationParamsMessage` and only install the
     native listener when it is set. Follow `hasScrollDelegate` / `hasLongPressDelegate`.
   - Adding a field to `CreationParamsMessage` or `WebViewSettingsMessage` breaks the
     `params()` / `settings()` helpers in `WebViewHostApiImplTest.kt` and `RunnerTests.swift`;
     update both (Swift memberwise initialisers are order-sensitive: insert in the Pigeon order).
   - `WebViewSettings.hashCode` uses `Object.hashAll`; `Object.hash` accepts at most 20 arguments.
   - Native errors for impossible states (for example no Activity or window) are
     `FlutterError` (Kotlin) / `PigeonError` (Swift) with the same code on both platforms.
5. Update `test/fake_host_api.dart` and add tests in `test/`. Add an integration test in
   `example/integration_test/` when the behaviour depends on the real WebView.
   Robolectric limits: `ShadowParcel` cannot unmarshall, `WebView.restoreState` is a stub and
   `saveState` always returns a value, so cover those round trips in the integration test.
   Integration tests that need a viewport (screenshot, `hitTest`) call
   `harness.waitForSize(tester)` first, or the page has zero size on iOS.
6. Run `dart format`, `flutter analyze`, `flutter test`, and record the change in
   `CHANGELOG.md` under `## Unreleased`.

## Verify locally

- `mise run check` (format, Pigeon freshness, analyze, test, ktlint, swift-format). Its Pigeon
  step does `git diff --exit-code`, so commit your change first or it reports the edit as stale.
- Android unit tests: `cd example/android && ./gradlew :advanced_webview:testDebugUnitTest`
  with `ANDROID_HOME=/opt/homebrew/share/android-commandlinetools` and `JAVA_HOME` set to the
  mise Temurin 21 (`mise where java`); Android Studio's JBR is too new for Robolectric.
- Android integration tests: boot the `fmw_api36` emulator, then
  `cd example && flutter test integration_test -d emulator-5554`. If adb reports `offline`,
  run `adb reconnect offline`.
- iOS: `mise run check:ios` runs the SwiftPM build, integration tests and XCTest. Run it from a
  copy of the repo named `advanced_webview` if the worktree directory name clashes with SwiftPM.

## Done when

- Generated files are regenerated and committed in the same change (CI runs Pigeon and
  fails on `git diff`).
- Android and iOS implementations have matching names and behaviour.
- The public API change is documented and tested.
