# コントローラとウィジェット

## コントローラ1つ = WebView 1つ

`MobileWebViewController` は生成した時点でネイティブの WebView を作り、`dispose()` を呼ぶまで破棄しません。
`MobileWebView` ウィジェットは、コントローラが持っている WebView を表示するだけです。

そのため、ウィジェットがツリーから外れても（タブ切替や画面遷移）ページはリセットされません。
不要になったら `dispose()` を呼んでください。

```dart
final controller = MobileWebViewController()..loadUrl('https://flutter.dev');

// build
MobileWebView(controller: controller);

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

## コールバック

コンストラクタで渡します。

```dart
MobileWebViewController(
  onPageStarted: (url) {},
  onPageFinished: (url) {},
  onProgress: (progress) {},   // 0-100
  onTitleChanged: (title) {},
  onWebResourceError: (error) {
    // error.errorCode はプラットフォーム依存:
    // Android は WebViewClient.ERROR_*、iOS は NSError.code。
  },
);
```
