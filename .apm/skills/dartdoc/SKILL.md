---
name: dartdoc
description: Write and verify dartdoc (`///`) API reference comments for the advanced_webview public API, including the Android/iOS native API each member uses, and check them with `fvm dart doc`. Use when adding or changing public members, or when improving the pub.dev API reference.
---

# Writing dartdoc

pub.dev builds the API reference (like the `flutter_inappwebview` pages) from the `///`
comments on the public API when a version is published. There is nothing else to author:
good comments plus a clean `dart doc` run is the whole job. Read `AGENTS.md` first; it
takes precedence over this skill. Comments are English (hard rule: code comments and
dartdoc in English).

## What counts as public

Everything reachable from `lib/advanced_webview.dart` exports, including constructors,
fields, getters, callback typedefs and enum values. Every one needs a comment
(AGENTS.md rule 5). Never document or hand-edit `lib/src/platform/messages.g.dart`; it is
not exported.

## Comment shape

1. **Summary**: one sentence, own paragraph, starts with a third-person verb for members
   ("Loads [url] ...") or a noun phrase for classes and fields ("The title of ..."). End
   with a period. This line is what the index pages show.
2. **Details** (only if needed): behaviour, defaults, units, nullability, what the
   `Future` completes with, thrown errors, and when callbacks fire. Mention which
   thread/isolate rules matter only if they do.
3. **Platform notes**: required whenever a member reaches native code or behaves
   differently per platform. Put the native APIs in a final paragraph, with real links:

   ```dart
   /// Loads [url], optionally with extra request [headers].
   ///
   /// Completes when the load has been started, not when the page has finished
   /// loading; use [onPageFinished] for that.
   ///
   /// Android: `WebView.loadUrl(String, Map)`.
   /// iOS: `WKWebView.load(_:)` with a `URLRequest`.
   ```

   Rules for that paragraph:
   - Label with `Android:` / `iOS:` (not `Platform:`), one line each. If both are the
     same behaviour, still name both APIs. Use `Android and iOS differ:` before a
     behavioural difference and describe it.
   - Cite only native APIs the Kotlin/Swift sources really call (check
     `android/src/main/kotlin/...` and `ios/advanced_webview/Sources/...`).
   - The list must agree with that member's entry in `website/data/api-mapping.json`
     (`android.apis` / `ios.apis`, `status`). If you change one, change the other, in
     English and Japanese text where the entry has it. `cd website && bun run check:mapping`
     catches drift. Members marked `dartOnly` have no platform notes.
4. **Example** (optional, for entry points like the controller, widget and settings):
   a fenced ```` ```dart ```` block that compiles against the current API.

## Conventions

- Reference identifiers with `[Name]` (resolved by dartdoc): `[AdvancedWebViewController.loadUrl]`,
  `[WebViewSettings.javaScriptEnabled]`. Use backticks only for things dartdoc cannot
  resolve (JS, native types, literals).
- Document `window.<name>.postMessage(String)`, main-frame-only navigation decisions and
  JSON decoding (`undefined` -> `null`) wherever they apply (AGENTS.md rule 6).
- Don't restate the signature ("The url parameter"); say what the value means and its
  default. Describe each named parameter only when it isn't obvious, with `[param]`.
- Mark unsupported or partial platform behaviour explicitly; do not leave it implied.
- Use `@Deprecated('Use [x] instead.')` rather than only prose for deprecations.
- Don't use `{@template}`/`{@macro}` unless the same text is repeated three times or more.
- Library-level overview goes on `library advanced_webview;` in `lib/advanced_webview.dart`
  (what the package is, a minimal example, and the lifetime rule: the controller owns the
  WebView, `dispose()` it).

## Verify

Run from the repo root, through FVM:

```sh
fvm dart format $(git ls-files '*.dart' | grep -v '\.g\.dart$')
fvm flutter analyze
fvm dart doc --validate-links
```

- `dart doc` output goes to `doc/api/` (git-ignored; never commit it). Read the warnings:
  unresolved `[references]`, "no documentation" for public members, broken links. Fix
  every warning that points at `lib/`. Warnings on the package landing page (generated
  from `README.md`, "linked to from" is `package-advanced_webview`) about repo files such as
  `README.ja.md`, `LICENSE`, `CONTRIBUTING.md` or `AGENTS.md` are expected: dartdoc doesn't
  copy those files into `doc/api/`, so the relative links dangle only there.
- Optionally open `doc/api/index.html` (or run `fvm dart pub global activate dhttpd` /
  any static server) and check the class and member pages read like the pub.dev reference.
- If `fvm` or the Dart SDK is not available in your environment, say so instead of
  claiming the docs were verified.
- Enabling the `public_member_api_docs` lint in `analysis_options.yaml` makes `flutter
  analyze` flag missing comments; do it only together with a change that documents the
  whole API.

## Done when

- Every public member exported from `lib/advanced_webview.dart` has a summary sentence,
  and every member that calls native code has Android and iOS notes.
- Platform notes match `website/data/api-mapping.json` and `bun run check:mapping` passes.
- `fvm dart doc --validate-links` reports no warnings for `lib/` (README link warnings aside), and `fvm dart format`
  and `fvm flutter analyze` are clean.
- User-visible changes are in `CHANGELOG.md` under `## Unreleased`; the guide pages in
  `website/guide/` and `website/ja/guide/` do not contradict the comments.

## Notes

- If you edit this skill, run `apm install --target agent-skills,claude,codex` and commit
  `apm.lock.yaml` with it (APM 0.33.0). Generated `.agents/` and `.claude/` stay uncommitted.
