# アーキテクチャと設計判断

この文書は、開発者向けに設計の方針と制約をまとめたものです。
利用方法は[ドキュメントサイト](https://imk1t.github.io/advanced_webview/ja/)、
開発手順は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## 方針

- 対象は **Android と iOS のみ**。Web / macOS / Windows / Linux は扱わない。
- `flutter_inappwebview` の機能設計（コントローラ、ナビゲーション制御、JSブリッジ、設定）は参考にしつつ、
  **公開APIを小さく保ち、プラットフォーム境界を1ファイルに集約する**ことで保守性を優先する。

## レイヤー構成

```
lib/
  advanced_webview.dart            公開API（ここからexportしたものだけが公開）
  src/
    controller.dart            AdvancedWebViewController（WebView 1つ = コントローラ 1つ）
    widget.dart                AdvancedWebView（AndroidView / UiKitView）
    settings.dart              共通・Android・iOS の設定（不変オブジェクト）
    navigation.dart            NavigationRequest / WebResourceError / コールバック型
    platform/
      messages.g.dart          Pigeon生成コード（手で編集しない）
      event_dispatcher.dart    native→Dart イベントを webViewId で振り分け
pigeons/messages.dart          Dart⇔ネイティブの契約（唯一の定義元）
android/.../                   Kotlin 実装（AdvancedWebView, Registry, HostApiImpl, Factory）
ios/advanced_webview/Sources/...   Swift 実装（同じ構成）
ios/advanced_webview/Package.swift Swift Package Manager 用マニフェスト
ios/advanced_webview.podspec       CocoaPods 用（Package.swift と同じソースを参照）
```

Android と iOS は **同じクラス構成・同じ名前** に揃えている。片方を直したらもう片方の同名ファイルを見ればよい。

### WebView のライフサイクル

1. `AdvancedWebViewController` の生成時に Dart が `webViewId` を採番し、`HostApi.create` でネイティブWebViewを作る。
2. `AdvancedWebView` ウィジェットが `create` 完了を待ってから PlatformView を要求し、ネイティブの Factory は
   `webViewId` で Registry から既存インスタンスを引き当てるだけ。
3. `controller.dispose()` で破棄。ウィジェットの破棄では WebView は消えない（画面遷移やタブ切替で状態を保てる）。

HostApi / FlutterApi は全 WebView で1組を共有し、操作とイベントを `webViewId` で振り分ける。
`WebViewEventDispatcher` がネイティブからのイベントを対応するコントローラへ届ける。
PlatformView ごとにチャネルを追加したり、ウィジェットにネイティブ WebView の破棄を任せたりしない。

## Pigeon の採用

Pigeon のバージョンは [pubspec.yaml](pubspec.yaml) で固定している。
`pigeons/messages.dart` を Dart・Kotlin・Swift 間の契約の唯一の定義元とする。

### 理由

| 観点 | MethodChannel を手書きする場合 | 本パッケージの Pigeon 利用 |
| --- | --- | --- |
| 型安全 | 文字列のメソッド名と `Map<String, dynamic>` の手動変換 | Dart/Kotlin/Swift の型・nullabilityを生成 |
| 契約の所在 | Dart・Kotlin・Swift の3か所に分散 | `pigeons/messages.dart` の1ファイル |
| 変更時の不整合 | メソッド名やデータ形式の食い違いをテストで確認する必要がある | 生成された型に対する不整合をコンパイル時に検出できる |
| 非同期 | コールバックを手で管理 | Kotlin `suspend` / Swift `async` で生成 |
| CI | 契約の一致を独自に検証する必要がある | 再生成して `git diff` で生成漏れを検出（CIで実施） |

Pigeon によって通信コードの生成を自動化し、手書きコードを機能の実装とプラットフォーム差異の吸収に集中させる。

### HostApi 方式 と ProxyApi 方式

本パッケージでは、ネイティブクラスを直接 Dart に公開する ProxyApi 方式ではなく、
**通常の HostApi / FlutterApi + `webViewId`** で機能単位の契約を定義している。

- WKWebView / android.webkit のクラス構成を公開 API に持ち込まず、両プラットフォームに共通の操作を公開する。
- 本パッケージは「Android と iOS で同じ振る舞いを持つ小さな API」が目的なので、差異はネイティブ側で吸収し、
  Dart から見える契約は機能単位（`loadUrl`, `evaluateJavaScript` など）にした方が読みやすく変更しやすい。
- 将来、細かいネイティブAPIを個別に公開したくなった場合は、その部分だけ ProxyApi を導入できる。

### 注意点

- Pigeon 生成コードはコミットする（利用者は Pigeon を実行しない）。`pigeons/messages.dart` を変更したら
  `mise exec -- dart run pigeon --input pigeons/messages.dart` を実行する。CI が生成漏れを検出する。
- フィールド名 `description` は Swift の `NSObject.description` と衝突するため使えない（`message` を使用）。
- Kotlin の `suspend` API のために `kotlinx-coroutines-android` が必要。

## プラットフォーム差異の扱い

| 機能 | Android | iOS | 方針 |
| --- | --- | --- | --- |
| ナビゲーション判定 | 同期で答える必要がある | `decisionHandler` で非同期可 | Android はいったんキャンセル→Dartに問い合わせ→許可なら再ロード。両OSとも **メインフレームかつページ起点の遷移のみ** Dart に問い合わせる（`loadUrl` / `loadHtmlString` / reload / 戻る・進む は問い合わせない） |
| JS チャネル | `addJavascriptInterface` | `WKScriptMessageHandler` | iOS でユーザースクリプトを注入し、両OSとも `window.<name>.postMessage(String)` に統一 |
| JS 実行結果 | JSON 文字列 | `Any` | iOS 側で JSON 化し、Dart で `jsonDecode`。`undefined` は両OS `null` |
| 設定の後変更 | 設定ごとに定義 | 一部は生成時のみ | 生成時のみ有効な項目は各設定クラスの dartdoc に "creation only" と明記 |

共通設定は `WebViewSettings`、OS 固有の設定は `AndroidWebViewSettings` と `IOSWebViewSettings` に分け、
それぞれ `WebViewSettings.android` / `ios` に渡す。他方の OS 向け設定は無視する。
設定の適用時期や既定値は [lib/src/settings.dart](lib/src/settings.dart) と
[設定ガイド](https://imk1t.github.io/advanced_webview/ja/guide/settings) を参照する。

## 機能と変更履歴の参照先

- 利用可能な機能と使用例は[ガイド](https://imk1t.github.io/advanced_webview/ja/guide/getting-started)を参照する。
- Dart API とネイティブ API の対応は [website/data/api-mapping.json](website/data/api-mapping.json) で管理し、
  [API マッピング](https://imk1t.github.io/advanced_webview/ja/guide/api-mapping)として公開する。
- 公開 API は [lib/advanced_webview.dart](lib/advanced_webview.dart) の export を基準とし、
  利用者に影響する変更は [CHANGELOG.md](CHANGELOG.md) に記録する。
