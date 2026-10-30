# Getting started

`flutter_mobile_webview` is a Flutter WebView plugin for **Android and iOS only**, built on
[Pigeon](https://pub.dev/packages/pigeon). It borrows feature ideas from
`flutter_inappwebview`, but favours maintainability with a small public API and a single,
centralised platform contract.

## Supported platforms

| Android | iOS |
| --- | --- |
| API 24+ | iOS 18+ |

On iOS, both Swift Package Manager and CocoaPods are supported. The plugin builds with
either, depending on your Flutter setting (`flutter config --enable-swift-package-manager` /
`--no-enable-swift-package-manager`); no extra setup is needed in your app.

## Installation

The package is not on pub.dev yet. Until the first release, depend on the Git repository:

```yaml
dependencies:
  flutter_mobile_webview:
    git:
      url: https://github.com/imk1t/flutter_mobile_webview.git
```

## A minimal example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_mobile_webview/flutter_mobile_webview.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  final controller = MobileWebViewController(
    onPageFinished: (url) => debugPrint('loaded $url'),
  )..loadUrl('https://flutter.dev');

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MobileWebView(controller: controller);
}
```

## Current features

- Load a URL or an HTML string; reload, stop, go back and forward
- Get the current URL and title
- Run JavaScript (with or without a return value)
- JavaScript channels (messages from JS to Dart)
- Navigation decisions (main frame)
- Callbacks: page started / finished, progress, title changed, load errors
- Settings: JavaScript enabled, User-Agent, media autoplay, inline playback (iOS),
  zoom (Android), transparent background
