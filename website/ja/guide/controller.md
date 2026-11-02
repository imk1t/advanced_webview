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

await controller.reload();
await controller.stopLoading();
if (await controller.canGoBack()) await controller.goBack();
if (await controller.canGoForward()) await controller.goForward();

final url = await controller.currentUrl();
final title = await controller.title();
```

## スクリーンショット

```dart
final png = await controller.takeScreenshot(); // Uint8List?（PNG）
```

ページ全体ではなく、表示されている領域だけを取得します。ビューのサイズが 0 の間は `null` を返します。

## スクロール

```dart
await controller.scrollTo(0, 500);        // 絶対位置（アニメーションなし）
await controller.scrollBy(0, 100);        // 相対移動
final offset = await controller.scrollPosition(); // Offset
```

オフセットは両プラットフォームとも論理ピクセルです。スクロール位置を追いたい場合は、コンストラクタに
`onScrollChanged: (offset) {}` を渡します。スクロールの1ステップごとに呼ばれるため、処理は軽くしてください。
未指定ならスクロールイベントはプラットフォームチャネルを通りません。

## ページ内検索

```dart
final result = await controller.findText('flutter');
// result.found。Android では result.matchCount と result.activeMatchIndex も入ります。
await controller.findText('flutter');                 // 同じ検索語: 次の一致へ
await controller.findText('flutter', forward: false); // 前の一致へ
await controller.clearMatches();                      // ハイライトを消す
```

iOS は一致の有無だけを返すため、`matchCount` と `activeMatchIndex` は `null` になります。

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

## ファイルのアップロード {#file-uploads}

`<input type="file">` は、Dart 側のコードなしで両プラットフォームで動作します。

- **iOS** は WebKit 標準のピッカーを使います。アプリの `Info.plist` に `NSPhotoLibraryUsageDescription` を、
  ページが写真や動画を撮影する場合は `NSCameraUsageDescription` / `NSMicrophoneUsageDescription` も追加してください。
- **Android** はシステムのドキュメントピッカー(`FileChooserParams.createIntent()`)を開きます。前面の Activity が必要ですが、
  Flutter アプリには常にあります。`capture`(カメラ)属性は特別扱いしません。
