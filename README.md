# flutter_mobile_webview

English | [日本語](README.ja.md)

[![CI](https://github.com/imk1t/flutter_mobile_webview/actions/workflows/ci.yaml/badge.svg)](https://github.com/imk1t/flutter_mobile_webview/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A type-safe Flutter WebView plugin for Android and iOS only, built on Pigeon.
It borrows feature ideas from `flutter_inappwebview`, but favours maintainability with a
small public API and a single, centralised platform contract.

For design decisions (such as why Pigeon was chosen), see
[doc/architecture.md](doc/architecture.md) (Japanese).

## Supported platforms

| Android | iOS |
| --- | --- |
| API 24+ | iOS 15+ |

## Usage

```dart
final controller = MobileWebViewController(
  javaScriptChannels: {'Bridge': (message) => print(message)},
  onPageFinished: (url) => print('loaded $url'),
  onNavigationRequest: (request) => request.url.startsWith('https://')
      ? NavigationDecision.navigate
      : NavigationDecision.prevent,
)..loadUrl('https://flutter.dev');

// build
MobileWebView(controller: controller);

// Run JavaScript (the result is already decoded from JSON)
final title = await controller.runJavaScriptReturningResult('document.title');

// When you no longer need it
await controller.dispose();
```

On both platforms, JavaScript can call `window.Bridge.postMessage('hello')`.

## Current features

- Load a URL or an HTML string; reload, stop, go back and forward
- Get the current URL and title
- Run JavaScript (with or without a return value)
- JavaScript channels (messages from JS to Dart)
- Navigation decisions (main frame)
- Callbacks: page started / finished, progress, title changed, load errors
- Settings: JavaScript enabled, User-Agent, media autoplay, inline playback (iOS),
  zoom (Android), transparent background

## Development

Flutter is managed with [FVM](https://fvm.app) (the version is pinned in `.fvmrc`).

```sh
fvm install                                          # install the pinned Flutter
fvm flutter pub get
fvm dart run pigeon --input pigeons/messages.dart   # after editing pigeons/messages.dart
fvm flutter analyze
fvm flutter test                                     # Dart unit tests
cd example && fvm flutter test integration_test      # integration tests on a device or simulator
```

Native code is formatted and linted with ktlint (Kotlin) and swift-format (Swift).
See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow.

## Contributing

Issues and pull requests are welcome, in English or Japanese. Please read
[CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md).
Please report security vulnerabilities by following [SECURITY.md](SECURITY.md), not
through public issues.

Instructions for AI coding agents are in [AGENTS.md](AGENTS.md) (shared skills are
distributed with [APM](https://github.com/microsoft/apm) via `apm.yml`).

## License

[MIT License](LICENSE)
