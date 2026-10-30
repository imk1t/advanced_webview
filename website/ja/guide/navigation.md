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
