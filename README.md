# flutter_mobile_webview

Android と iOS に絞った、Pigeon ベースの型安全な Flutter WebView プラグインです。
`flutter_inappwebview` の機能設計を参考にしつつ、小さな公開APIと1か所に集約したプラットフォーム契約で保守性を優先しています。

設計判断（Pigeon 採用理由など）は [docs/architecture.md](docs/architecture.md) を参照してください。

## 対応プラットフォーム

| Android | iOS |
| --- | --- |
| API 24+ | iOS 15+ |

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

```sh
flutter pub get
dart run pigeon --input pigeons/messages.dart   # pigeons/messages.dart を変更したとき
flutter analyze
flutter test                                     # Dart 単体テスト
cd example && flutter test integration_test      # 実機・シミュレータでの結合テスト
```
