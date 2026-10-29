# Contributing to flutter_mobile_webview

Thanks for your interest in contributing! Issues and pull requests are welcome in
English or Japanese (日本語での Issue / PR も歓迎します).

## Before you start

- Search existing [issues](https://github.com/imk1t/flutter_mobile_webview/issues) first.
- For anything larger than a small fix (new APIs, behaviour changes), open an issue
  to discuss the design before writing code. The goal of this package is a **small,
  maintainable API for Android and iOS only**; please read
  [doc/architecture.md](doc/architecture.md) to understand the design decisions.
- Web, macOS, Windows and Linux support is out of scope.

## Development setup

Requirements: Flutter (stable channel), Xcode for iOS, Android SDK + JDK 17 for Android.

```sh
flutter pub get
flutter analyze
flutter test                                    # Dart unit tests
cd example && flutter test integration_test     # on a device or simulator
```

## Project rules

- **The platform contract lives only in `pigeons/messages.dart`.** After changing it,
  regenerate the bindings and commit the generated files:

  ```sh
  dart run pigeon --input pigeons/messages.dart
  ```

  Never edit `*.g.dart`, `Messages.g.kt` or `Messages.g.swift` by hand. CI fails if
  the generated code is out of date.
- **Keep Android and iOS mirrored.** Both platforms use the same class names
  (`MobileWebView`, `WebViewRegistry`, `WebViewHostApiImpl`, `MobileWebViewFactory`,
  `MobileWebViewPlugin`). A change on one side normally needs the same change on the other.
- Only symbols exported from `lib/flutter_mobile_webview.dart` are public API.
- Format Dart code with `dart format` (generated `*.g.dart` files are excluded).
- Add or update tests for behaviour changes (`test/` uses a fake HostApi).
- Update `CHANGELOG.md` under `## Unreleased` for user-visible changes.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Make your change, keeping the PR focused on one topic.
3. Make sure `flutter analyze`, `flutter test` and formatting pass locally.
4. Fill in the pull request template. CI builds the example app for Android and iOS.

By contributing, you agree that your contributions will be licensed under the
[MIT License](LICENSE).

## Using AI coding agents

AI-assisted contributions are welcome. Agent instructions live in [AGENTS.md](AGENTS.md)
and are shared through [APM](https://github.com/microsoft/apm) (`apm.yml`); see
AGENTS.md for setup. You are responsible for reviewing and understanding every line
you submit.

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating
you are expected to uphold it.
