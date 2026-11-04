# 証明書と HTTP 認証

既定では、WebView は不正な証明書のページを拒否し、HTTP 認証もキャンセルします。2 つのコールバックで、
アプリ側が判断を引き取れます。

## 証明書エラー

```dart
final controller = AdvancedWebViewController(
  onSslError: (error) {
    // error.host, error.url, error.message
    return error.host == 'dev.example.test'
        ? SslErrorDecision.proceed
        : SslErrorDecision.cancel;
  },
);
```

`onSslError` は、期限切れ、まだ有効でない、ホスト名が一致しない、信頼できない証明書のときに、
ページとそのサブリソースの両方で呼ばれます。`SslErrorDecision.proceed` はそのまま読み込み、
**TLS がユーザーに与える保護をなくします**。開発サーバーなど内容を把握している証明書に限って使い、
「エラーをすべて無視する」スイッチにはしないでください。コールバックがない場合や例外を投げた場合は、
両 OS で読み込みを拒否します。

`message` の文言はプラットフォームごとに異なります。解析しないでください。

## HTTP 認証

```dart
var attempts = 0;
final controller = AdvancedWebViewController(
  onHttpAuthRequest: (request) {
    // request.host, request.realm
    if (++attempts > 3) return null; // 延々と聞かれ続けないよう、あきらめる
    return const HttpAuthCredentials(username: 'user', password: 'secret');
  },
);
```

認証情報を返すか、キャンセルなら `null` を返します。HTTP Basic、Digest、NTLM に対応します。認証情報が間違っていると
サーバーは再度要求するため、数回で打ち切ってください。コールバックがない場合、Android ではキャンセルし、
iOS ではシステムの既定処理になり、こちらも失敗します。iOS のプロキシ認証はシステムに任せます。

認証情報はシステムがセッション中だけ保持し、プラグインは保存しません。ログに出さず、本物の値を
コードに直書きしないでください。
