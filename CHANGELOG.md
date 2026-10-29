# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

- Add MIT license, community health files, issue/PR templates and pub.dev metadata.
- Pin Flutter 3.47.8 with FVM (`.fvmrc`); CI uses the same version.
- Android: detach the WebView from its previous container when a controller is shown
  by a new `MobileWebView`, so re-attaching a controller does not fail.
- Add native unit tests (Robolectric on Android, XCTest on iOS) and run the integration
  tests on an Android emulator and an iOS simulator in CI.
- Add AI agent configuration (`AGENTS.md`, APM with shared skills from `imk1t/apm-shared`).

## 0.0.1

- Initial scaffold: Pigeon-based platform contract, Android (Kotlin) and iOS (Swift)
  implementations, and an example app.
