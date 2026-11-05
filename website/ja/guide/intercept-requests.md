# リクエストのインターセプト

ページやリソースを、ネットワークの代わりに Dart から返せます。処理したい URL スキームとコールバックを渡すと、
コールバックが応答を返します。`null` を返すとリクエストはそのまま通ります。

```dart
final controller = AdvancedWebViewController(
  interceptSchemes: ['app'],
  onInterceptRequest: (request) async {
    // request.url, request.method, request.headers, request.isMainFrame
    if (request.url == 'app://host/index.html') {
      return InterceptResponse.text('<h1>Served from Dart</h1>');
    }
    final bytes = await loadBytesFor(request.url);
    return InterceptResponse(body: bytes, mimeType: 'image/png');
  },
);

await controller.loadUrl('app://host/index.html');
```

`InterceptResponse` はボディのバイト列、`mimeType`（`charset` を含められます）、`statusCode`（既定は 200）、
追加の `headers` を持ちます。`InterceptResponse.text` は UTF-8 テキスト用の近道です。

`interceptSchemes` と `onInterceptRequest` は必ず一緒に指定します。コールバックはページ自身と、そのページが
要求するすべてのサブリソース（スクリプト、画像、`fetch`）で呼ばれるため、`app://host/` から配信したページ内の
相対 URL もコールバックに届きます。リクエストのボディは取得できません。

## 違い

- **iOS で扱えるのはカスタムスキームだけです。** WebKit は `http`、`https`、`file`、`data` などの組み込みスキームを
  アプリがインターセプトすることを許さないため、`interceptSchemes` のそれらの項目は iOS では無視されます。
  Android は `https` を含むすべてのスキームをインターセプトできます。移植性を保つには `app` のような
  カスタムスキームを使ってください。
- **`null` の意味が違います。** Android ではそのままネットワークから読み込みます。iOS のカスタムスキームには
  フォールバック先のネットワークがないため、`null`（とコールバックが投げたエラー）はサポート外 URL のエラーで
  リクエストを失敗させます。
- **リダイレクト。** Android は応答に 300〜399 のステータスを使えず、その場合はリクエストを通します。
  最終的な内容を直接返してください。
- **タイムアウト。** Android はコールバックを最大約10秒待ち、その後リクエストを通します。iOS はコールバックが
  終わるまで待ちます。
- **スレッド。** どちらも UI スレッドはブロックしません。Android では WebView が自身の IO スレッドで問い合わせ、
  Dart の応答までそのスレッドが待つため、コールバックは短く保ってください。遅いコールバックが
  遅らせるのはそのリクエストだけです。
- **オリジン間アクセス。** あるオリジンのページが別のオリジンから取得する場合は、通常の CORS ヘッダ
  （例: `Access-Control-Allow-Origin`）を `InterceptResponse.headers` に付ける必要があります。

背後のネイティブ API は [API 対応表](./api-mapping) を参照してください。
