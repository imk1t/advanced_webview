# Security Policy

## Supported versions

Until 1.0.0, only the latest published version receives security fixes.

| Version | Supported |
| ------- | --------- |
| latest  | ✅        |
| older   | ❌        |

## Reporting a vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Report them privately via
[GitHub Security Advisories](https://github.com/imk1t/advanced_webview/security/advisories/new)
("Report a vulnerability" on the Security tab).

Please include:

- affected version(s) and platform (Android / iOS, OS version)
- a description of the issue and its impact
- steps or a minimal project to reproduce

You should receive an acknowledgement within 7 days. We will keep you informed of the
progress towards a fix and credit you in the advisory unless you prefer otherwise.

## Scope notes

This plugin wraps the system WebView (`android.webkit.WebView` / `WKWebView`).
Vulnerabilities in the WebView engine itself should be reported to Google or Apple.
Issues in how this plugin exposes the WebView (for example the JavaScript channel
bridge, navigation decisions, or default settings) are in scope.
