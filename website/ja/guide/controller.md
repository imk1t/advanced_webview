# コントローラとウィジェット

## コントローラ1つ = WebView 1つ

`AdvancedWebViewController` は生成した時点でネイティブの WebView を作り、`dispose()` を呼ぶまで破棄しません。
`AdvancedWebView` ウィジェットは、コントローラが持っている WebView を表示するだけです。

そのため、ウィジェットがツリーから外れても（タブ切替や画面遷移）ページはリセットされません。
不要になったら `dispose()` を呼んでください。

```dart
final controller = AdvancedWebViewController()..loadUrl('https://flutter.dev');

// build
AdvancedWebView(controller: controller);

// 不要になったら
await controller.dispose();
```

## 読み込み

```dart
await controller.loadUrl('https://example.com', headers: {'X-Token': 'abc'});
await controller.loadHtmlString('<h1>Hello</h1>', baseUrl: 'https://example.com');

// pubspec.yaml の `flutter: assets:` に宣言した Flutter アセット
await controller.loadFlutterAsset('assets/web/index.html');

// 端末上のファイル
await controller.loadFile('/path/to/page.html');

// POST リクエスト
await controller.loadRequest(
  'https://example.com/login',
  method: WebViewHttpMethod.post,
  body: Uint8List.fromList(utf8.encode('user=a&pass=b')),
);

await controller.reload();
await controller.stopLoading();
if (await controller.canGoBack()) await controller.goBack();
if (await controller.canGoForward()) await controller.goForward();

final url = await controller.currentUrl();
final title = await controller.title();
```

新しい 3 つの読み込みのプラットフォーム別の注意点です。

- `loadFlutterAsset`: 相対リンクは同じフォルダのアセットに解決されます。Android は
  `https://appassets.androidplatform.net/assets/flutter_assets/...` で配信し、`allowFileAccess` は不要です。
  存在しないアセットは 404 として読み込まれます（`onHttpError` を参照）。iOS はアプリバンドルのファイルを、
  そのフォルダへの読み取り権限付きで読み込み、存在しないアセットは `not-found` を投げます。
- `loadFile`: Android は `AndroidWebViewSettings.allowFileAccess`（既定は無効）が必要で、無効の場合は
  `file-access-disabled` を投げます。iOS は存在しないファイルに `not-found` を投げます。
- `loadRequest`: Android は POST の body を `application/x-www-form-urlencoded` で送り、POST にヘッダーを
  付けられません（渡すと `unsupported` を投げます）。iOS はヘッダーと body をそのまま送ります。
  `body` は `WebViewHttpMethod.post` のときだけ指定できます。

## スクリーンショット

```dart
final png = await controller.takeScreenshot(); // Uint8List?（PNG）
```

ページ全体ではなく、表示されている領域だけを取得します。ビューのサイズが 0 の間は `null` を返します。

## PDF の書き出し

```dart
final pdf = await controller.createPdf(); // Uint8List（PDF のバイト列）
```

先にページの読み込み完了を待ってください。Android は印刷と同じように A4 ページへレイアウトするため、ページの印刷用スタイルが
適用されます。iOS は画面用スタイルのまま、コンテンツ全体の高さを持つ1ページを返します。失敗時はコード `pdf-failed` の
`PlatformException` を投げます。

## スクロール

```dart
await controller.scrollTo(0, 500);        // 絶対位置（アニメーションなし）
await controller.scrollBy(0, 100);        // 相対移動
final offset = await controller.scrollPosition(); // Offset
```

オフセットは両プラットフォームとも論理ピクセルです。スクロール位置を追いたい場合は、コンストラクタに
`onScrollChanged: (offset) {}` を渡します。スクロールの1ステップごとに呼ばれるため、処理は軽くしてください。
未指定ならスクロールイベントはプラットフォームチャネルを通りません。

## 状態の保存と復元

```dart
final state = await controller.saveState();     // Uint8List?（履歴とスクロール位置）
// ... 後で（アプリ再起動後など）新しいコントローラで:
final restored = await controller.restoreState(state!); // false: 読めない場合は通常どおり読み込む
```

バイト列は中身が不透明でプラットフォーム依存です（Android は `Bundle` をマーシャルしたもの、iOS は
`WKWebView.interactionState` をアーカイブしたもの）。同じプラットフォームでのみ復元し、
`restoreState` が `false` を返したら破棄してください。まだ履歴がなければ `saveState` は `null` を返します。

## 印刷

```dart
await controller.printPage(jobName: 'Invoice');
```

システムの印刷ダイアログ（Android は `PrintManager`、iOS は `UIPrintInteractionController`）を開き、
表示された時点で戻ります。WebView が `AdvancedWebView` として画面に表示されている必要があり、
そうでない場合は `PlatformException`（コード `not-attached`）が投げられます。

## 長押しとヒットテスト

```dart
AdvancedWebViewController(
  onLongPress: (position) async {
    final hit = await controller.hitTest(position);
    // hit.type: none / link / image / imageLink。hit.linkUrl / hit.imageUrl
  },
);
```

`onLongPress` は WebView 内のタッチ位置を論理ピクセルで通知します。プラットフォーム標準の長押し動作
（テキスト選択やリンクメニュー）もそのまま動きます。`hitTest` は `document.elementFromPoint` で位置を調べるため、
メインフレームのみが対象で、両プラットフォームで同じ結果になります。独自のコンテキストメニューを作るときに使います。

## コンソールメッセージ

```dart
AdvancedWebViewController(
  onConsoleMessage: (message) {
    debugPrint('[${message.level.name}] ${message.message}');
  },
);
```

`onConsoleMessage` は、ページが任意のフレームで呼び出した `console.debug` / `log` / `info` / `warn` / `error` を通知します。
プラットフォーム標準のコンソール出力（Logcat、Web Inspector）もそのまま動きます。キャッチされなかった例外や
ブラウザー自身が出すメッセージは通知されません。Android ではスクリプトの URL と行番号が `sourceUrl` / `lineNumber`
に入りますが、iOS ではその情報がないため `null` です（WebKit にコンソールのコールバックがないため、ドキュメント開始時に
注入したスクリプトで `console` メソッドをラップしています）。Android では `console.info` が `log` として届くことがあります。
ページのデバッグでは `WebViewSettings.inspectable` と併用してください。

## ページ内検索

```dart
final result = await controller.findText('flutter');
// result.found、result.matchCount、result.activeMatchIndex
await controller.findText('flutter');                 // 同じ検索語: 次の一致へ
await controller.findText('flutter', forward: false); // 前の一致へ
await controller.clearMatches();                      // ハイライトを消す
```

「3 / 12」のような表示を同期するには、コンストラクタに `onFindResult` を渡します。現在の一致の位置、これまでの一致数、
カウントが確定したかどうかが届きます。

```dart
AdvancedWebViewController(
  onFindResult: (activeMatchIndex, numberOfMatches, isDone) {
    setState(() => label = '${activeMatchIndex + 1} / $numberOfMatches');
  },
);
```

Android は WebView がカウントする間、更新のたびに通知します（最後の更新まで `isDone` は `false`）。iOS は
`findText` の呼び出しごとに最終の更新を1回送ります。WebKit は一致数も位置も返さないため、iOS ではプラグインが
ページのテキスト中のクエリ数を数え、検索方向に沿って位置を保持します。どちらも best-effort で、iframe 内など
WebKit が別の方法で検索するテキストではハイライトと食い違うことがあります。

## コールバック

コンストラクタで渡します。

```dart
AdvancedWebViewController(
  onPageStarted: (url) {},
  onPageFinished: (url) {},
  onProgress: (progress) {},   // 0-100
  onTitleChanged: (title) {},
  onScrollChanged: (offset) {},
  onWebResourceError: (error) {
    // error.errorCode はプラットフォーム依存:
    // Android は WebViewClient.ERROR_*、iOS は NSError.code。
  },
);
```

## ファビコンと全画面表示 {#favicon-and-fullscreen}

```dart
AdvancedWebViewController(
  onFaviconChanged: (url) {}, // ページの読み込み完了ごとに通知。String?
  onEnterFullscreen: () {},   // アプリ側のクロームを隠す
  onExitFullscreen: () {},
);
```

`onFaviconChanged` はページの `<link rel="icon">` の URL を通知します。ページが宣言していない場合はオリジンの
`/favicon.ico`（存在しないことがあります）、HTTP 以外のページでは `null` です。WebKit には公開のファビコン API がなく、
Android はデコード済みのビットマップしか渡さないため、どちらもページのマークアップを読み取り、同じ結果になるようにしています。
画像の読み込みはアプリ側で行ってください（例: `Image.network`）。ページの読み込み完了後にスクリプトが追加したアイコンは
通知されません。

全画面表示はプラットフォームが行い、コールバックは通知するだけです。動画の全画面ボタンも `element.requestFullscreen()` も
使えます。Android ではプラグインが Activity のウィンドウをコンテンツで覆い、システムバーを隠し、戻る操作で全画面を終了します。
画面の回転は行わないため、横向きにしたい場合は `onEnterFullscreen` でアプリ側が向きを設定してください。
このリリース以前の Android は全画面表示自体に対応していませんでした。iOS は WebKit 独自の全画面ビューを表示し、
プラグインはそのために要素の全画面 API を有効にします。

## ファイルのアップロード {#file-uploads}

`<input type="file">` は、Dart 側のコードなしで両プラットフォームで動作します。

- **iOS** は WebKit 標準のピッカーを使います。アプリの `Info.plist` に `NSPhotoLibraryUsageDescription` を、
  ページが写真や動画を撮影する場合は `NSCameraUsageDescription` / `NSMicrophoneUsageDescription` も追加してください。
- **Android** はシステムのドキュメントピッカー(`FileChooserParams.createIntent()`)を開きます。前面の Activity が必要ですが、
  Flutter アプリには常にあります。`capture`(カメラ)属性は特別扱いしません。
