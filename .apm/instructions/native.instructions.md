---
description: Rules for the Android (Kotlin) and iOS (Swift) implementations
applyTo: "{android/src/**/*.kt,ios/**/*.swift}"
---
- Android and iOS are mirrored: same file names and class names
  (`MobileWebView`, `WebViewRegistry`, `WebViewHostApiImpl`, `MobileWebViewFactory`,
  `MobileWebViewPlugin`). A change on one platform needs the equivalent change on the other.
- The WebView is created in `WebViewHostApiImpl.create` and stored in `WebViewRegistry`;
  `MobileWebViewFactory` only looks it up by `webViewId`. Removal happens only on `dispose`.
- Absorb platform differences natively so Dart sees one behaviour:
  navigation decisions are main-frame only (Android cancels and re-loads after Dart allows),
  JavaScript channels are `window.<name>.postMessage(String)`, and JavaScript results are
  returned as JSON strings (`undefined` -> `null`).
- Android: minSdk 24, Kotlin coroutines for `suspend` APIs, call into Dart on the main thread.
- iOS: iOS 15+, `WKWebView`, Swift `async` for async APIs, keep `PrivacyInfo.xcprivacy` accurate.
