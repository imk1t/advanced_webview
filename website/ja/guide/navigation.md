# ナビゲーション

`onNavigationRequest` で遷移を許可・拒否できます。

```dart
final controller = AdvancedWebViewController(
  onNavigationRequest: (request) => request.url.startsWith('https://')
      ? NavigationDecision.navigate
      : NavigationDecision.prevent,
);
```

コールバックは `Future<NavigationDecision>` を返しても構いません。

## 通知される遷移

両 OS で同じ振る舞いです。

- **メインフレーム**の遷移だけが通知されます。
- ページ起点の遷移だけが通知されます（リンク、フォーム、`window.location`、リダイレクト）。
- コントローラから始めた読み込み（`loadUrl`、`loadHtmlString`、`reload`、`goBack`、`goForward`）は通知されません。

::: warning Android
Android は同期的に答える必要があるため、いったん遷移をキャンセルして Dart に問い合わせ、許可されたら
読み込み直します。読み込み直しは GET になるため、POST の本文やリダイレクトは保持されません。
:::

## 新しいウィンドウ

`window.open` や `target="_blank"` のリンクは新しいウィンドウを要求します。`onNewWindow` で処理します。

```dart
final controller = AdvancedWebViewController(
  onNewWindow: (url) => launchUrlString(url), // または別のコントローラで開く
);
```

`onNewWindow` を指定すると、WebView 自身は URL を読み込みません。指定しない場合は、両プラットフォームとも
同じ WebView で URL を読み込みます(`onNavigationRequest` も通ります)。Android では、一時的な WebView から
URL を取得し、すぐに破棄します。
