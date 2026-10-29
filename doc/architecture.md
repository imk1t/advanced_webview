# アーキテクチャと設計判断

## 方針

- 対象は **Android と iOS のみ**。Web / macOS / Windows / Linux は扱わない。
- `flutter_inappwebview` の機能設計（コントローラ、ナビゲーション制御、JSブリッジ、設定）は参考にしつつ、
  **公開APIを小さく保ち、プラットフォーム境界を1ファイルに集約する**ことで保守性を優先する。

## レイヤー構成

```
lib/
  flutter_mobile_webview.dart            公開API（ここからexportしたものだけが公開）
  src/
    controller.dart            MobileWebViewController（WebView 1つ = コントローラ 1つ）
    widget.dart                MobileWebView（AndroidView / UiKitView）
    settings.dart              WebViewSettings（不変オブジェクト）
    navigation.dart            NavigationRequest / WebResourceError / コールバック型
    platform/
      messages.g.dart          Pigeon生成コード（手で編集しない）
      event_dispatcher.dart    native→Dart イベントを webViewId で振り分け
pigeons/messages.dart          Dart⇔ネイティブの契約（唯一の定義元）
android/.../                   Kotlin 実装（MobileWebView, Registry, HostApiImpl, Factory）
ios/flutter_mobile_webview/Sources/...   Swift 実装（同じ構成）
ios/flutter_mobile_webview/Package.swift Swift Package Manager 用マニフェスト
ios/flutter_mobile_webview.podspec       CocoaPods 用（Package.swift と同じソースを参照）
```

Android と iOS は **同じクラス構成・同じ名前** に揃えている。片方を直したらもう片方の同名ファイルを見ればよい。

### WebView のライフサイクル

1. `MobileWebViewController` の生成時に Dart が `webViewId` を採番し、`HostApi.create` でネイティブWebViewを作る。
2. `MobileWebView` ウィジェットが `create` 完了を待ってから PlatformView を要求し、ネイティブの Factory は
   `webViewId` で Registry から既存インスタンスを引き当てるだけ。
3. `controller.dispose()` で破棄。ウィジェットの破棄では WebView は消えない（画面遷移やタブ切替で状態を保てる）。

`flutter_inappwebview` は PlatformView ごとに MethodChannel を作り、ウィジェットとWebViewの寿命が結びついている。
本パッケージは「コントローラが寿命を持つ」設計にして、チャネルを1組に固定した。

## Pigeon を採用するか

**結論: 採用する（pigeon ^29）。**

### 理由

| 観点 | MethodChannel 手書き（flutter_inappwebview） | Pigeon |
| --- | --- | --- |
| 型安全 | 文字列のメソッド名と `Map<String, dynamic>` の手動変換 | Dart/Kotlin/Swift の型・nullabilityを生成 |
| 契約の所在 | Dart・Kotlin・Swift の3か所に分散 | `pigeons/messages.dart` の1ファイル |
| 変更時の不整合 | 実行時にしか気付けない | 再生成でコンパイルエラーになる |
| 非同期 | コールバックを手で管理 | Kotlin `suspend` / Swift `async` で生成 |
| CI | 不整合の検出手段がない | 再生成して `git diff` で検出（CIで実施） |

`flutter_inappwebview` の保守性の悪さの大部分は、数百のメソッド名文字列と Map 変換が3言語に散らばっている点にある。
Pigeon はまさにこの部分を自動化するもので、公式の `webview_flutter` も Pigeon を使っている。

### HostApi 方式 と ProxyApi 方式

Pigeon には、ネイティブクラスを1対1で Dart に写す **ProxyApi**（`webview_flutter` の Android/iOS 実装が採用）もある。
今回は採用せず、**通常の HostApi / FlutterApi + `webViewId` 引数** にした。

- ProxyApi は WKWebView / android.webkit の API 全体を Dart 側にミラーするため、生成コードと Dart 側ラッパーが大きくなり、
  2プラットフォームの差異吸収を Dart 側で書くことになる。
- 本パッケージは「Android と iOS で同じ振る舞いを持つ小さな API」が目的なので、差異はネイティブ側で吸収し、
  Dart から見える契約は機能単位（`loadUrl`, `evaluateJavaScript` など）にした方が読みやすく変更しやすい。
- 将来、細かいネイティブAPIを個別に公開したくなった場合は、その部分だけ ProxyApi を導入できる。

### 注意点

- Pigeon 生成コードはコミットする（利用者は Pigeon を実行しない）。`pigeons/messages.dart` を変更したら
  `dart run pigeon --input pigeons/messages.dart` を実行する。CI が生成漏れを検出する。
- フィールド名 `description` は Swift の `NSObject.description` と衝突するため使えない（`message` を使用）。
- Kotlin の `suspend` API のために `kotlinx-coroutines-android` が必要。

## プラットフォーム差異の扱い

| 機能 | Android | iOS | 方針 |
| --- | --- | --- | --- |
| ナビゲーション判定 | 同期で答える必要がある | `decisionHandler` で非同期可 | Android はいったんキャンセル→Dartに問い合わせ→許可なら再ロード。両OSとも **メインフレームかつページ起点の遷移のみ** Dart に問い合わせる（`loadUrl` / `loadHtmlString` / reload / 戻る・進む は問い合わせない） |
| JS チャネル | `addJavascriptInterface` | `WKScriptMessageHandler` | iOS でユーザースクリプトを注入し、両OSとも `window.<name>.postMessage(String)` に統一 |
| JS 実行結果 | JSON 文字列 | `Any` | iOS 側で JSON 化し、Dart で `jsonDecode`。`undefined` は両OS `null` |
| 設定の後変更 | ほぼ可能 | 一部は生成時のみ | `WebViewSettings` のドキュメントに "creation only" と明記 |

## 今後の実装候補（flutter_inappwebview にある主な機能）

- Cookie 管理（`CookieManager` / `WKHTTPCookieStore`）
- 戻り値を返せる JS ハンドラ（`callHandler` 相当、Promise ベース）
- ユーザースクリプトの追加・削除
- ダウンロード、ファイル選択（`<input type="file">`）、権限リクエスト（カメラ・マイク）
- `onCreateWindow`（`target=_blank` / `window.open`）
- SSL エラー・HTTP認証のハンドリング
- スクリーンショット、PullToRefresh、検索（find in page）
