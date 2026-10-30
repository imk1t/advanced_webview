# flutter_mobile_webview

[English](README.md) | 日本語

[![CI](https://github.com/imk1t/flutter_mobile_webview/actions/workflows/ci.yaml/badge.svg)](https://github.com/imk1t/flutter_mobile_webview/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Android と iOS に絞った、Pigeon ベースの型安全な Flutter WebView プラグインです。
`flutter_inappwebview` の機能設計を参考にしつつ、小さな公開APIと1か所に集約したプラットフォーム契約で保守性を優先しています。

ドキュメント: https://imk1t.github.io/flutter_mobile_webview/ja/

設計判断（Pigeon 採用理由など）は [doc/architecture.md](doc/architecture.md) を参照してください。

## 対応プラットフォーム

| Android | iOS |
| --- | --- |
| API 24+ | iOS 15+ |

iOS は Swift Package Manager と CocoaPods の両方に対応しています。
Flutter の設定（`flutter config --enable-swift-package-manager` /
`--no-enable-swift-package-manager`）に応じてどちらでもビルドされ、利用側で追加の作業は不要です。

## 使い方

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

// JS 実行（結果は JSON からデコード済み）
final title = await controller.runJavaScriptReturningResult('document.title');

// 不要になったら
await controller.dispose();
```

JS からは両OS共通で `window.Bridge.postMessage('hello')` を呼べます。

## 現在の機能

- URL / HTML 文字列の読み込み、リロード、停止、戻る・進む
- 現在の URL・タイトルの取得
- JavaScript の実行（戻り値あり／なし）
- JavaScript チャネル（JS → Dart のメッセージ）
- ナビゲーション判定（メインフレーム）
- コールバック: ページ開始・完了、進捗、タイトル変更、読み込みエラー
- 設定: JavaScript 有効化、User-Agent、メディア自動再生、インライン再生（iOS）、ズーム（Android）、背景透過

## 開発

Flutter は [FVM](https://fvm.app) で管理しています（バージョンは `.fvmrc` で固定）。

```sh
fvm install                                          # 固定バージョンの Flutter を導入
fvm flutter pub get
fvm dart run pigeon --input pigeons/messages.dart   # pigeons/messages.dart を変更したとき
fvm flutter analyze
fvm flutter test                                     # Dart 単体テスト
cd example && fvm flutter test integration_test      # 実機・シミュレータでの結合テスト
```

ネイティブコードは ktlint（Kotlin）と swift-format（Swift）で整形・検査しています。手順の詳細は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## コントリビュート

Issue・Pull Request を歓迎します（日本語・英語どちらでも可）。[CONTRIBUTING.md](CONTRIBUTING.md) と [行動規範](CODE_OF_CONDUCT.md) を参照してください。
脆弱性の報告は Issue ではなく [SECURITY.md](SECURITY.md) の手順でお願いします。

AI コーディングエージェント向けの指示は [AGENTS.md](AGENTS.md) にあります（[APM](https://github.com/microsoft/apm) の `apm.yml` で配布）。

## ライセンス

[MIT License](LICENSE)
