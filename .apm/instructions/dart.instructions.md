---
description: Dart rules for the plugin's public API and tests
applyTo: "{lib/**/*.dart,test/**/*.dart,example/**/*.dart}"
---
- Only symbols exported from `lib/flutter_mobile_webview.dart` are public API; keep it small
  and document every public member with dartdoc (English).
- Public calls go through `MobileWebViewController._call` so they wait for native creation
  and throw after `dispose()`.
- Callbacks are delivered by `WebViewEventDispatcher` keyed by `webViewId`; do not add new
  channels.
- Test behaviour with `FakeHostApi` injected through the `@visibleForTesting` constructor
  parameters; do not depend on real platform channels in `test/`.
- Run `dart format`, `flutter analyze` and `flutter test` before finishing.
