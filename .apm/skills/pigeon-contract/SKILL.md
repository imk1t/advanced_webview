---
name: pigeon-contract
description: Add or change a Dart <-> native API of advanced_webview via pigeons/messages.dart, regenerate the bindings, and update the Dart, Kotlin and Swift sides together. Use for any change that crosses the platform channel.
---

# Changing the platform contract

`pigeons/messages.dart` is the only definition of the Dart <-> native contract. Read
`AGENTS.md` and `doc/architecture.md` first; they take precedence over this skill.

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
     unavoidable difference in dartdoc and `doc/architecture.md`.
4. Expose it in Dart through `AdvancedWebViewController` (wrap calls with `_call` so they
   wait for creation and fail after `dispose()`); for native -> Dart events, route them
   through `WebViewEventDispatcher` by `webViewId`.
5. Update `test/fake_host_api.dart` and add tests in `test/`. Add an integration test in
   `example/integration_test/` when the behaviour depends on the real WebView.
6. Run `dart format`, `flutter analyze`, `flutter test`, and record the change in
   `CHANGELOG.md` under `## Unreleased`.

## Done when

- Generated files are regenerated and committed in the same change (CI runs Pigeon and
  fails on `git diff`).
- Android and iOS implementations have matching names and behaviour.
- The public API change is documented and tested.
