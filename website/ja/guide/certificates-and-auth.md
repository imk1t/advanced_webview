# 証明書と HTTP 認証

既定では、WebView は不正な証明書のページを拒否し、HTTP 認証もキャンセルし、クライアント証明書も提示しません。
3 つのコールバックで、アプリ側が判断を引き取れます。

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

## クライアント証明書（相互 TLS）

```dart
final controller = AdvancedWebViewController(
  onClientCertRequest: (request) async {
    // request.host, request.port, request.realm（iOS のみ）
    final p12 = await loadMyPkcs12(); // Uint8List。たとえばセキュアストレージから
    return ClientCertResponse.proceed(pkcs12: p12, password: 'secret');
    // または: const ClientCertResponse.cancel()  - 接続を失敗させる
    // または: const ClientCertResponse.ignore()  - 証明書なしで続行する
  },
);
```

サーバーがクライアント証明書を要求したら、PKCS#12（`.p12` / `.pfx`）ファイルに入った証明書とそのパスワードで応答します。
ファイルの最初の鍵エントリが証明書チェーンとともに使われます。読み込めないファイル、誤ったパスワード、コールバックが
投げた例外はリクエストのキャンセルになります。3DES または AES で暗号化したファイルを使ってください。古すぎる、または新しすぎる
PKCS#12 の形式は、OS のバージョンによって読み込めないことがあります。

`ignore` は証明書なしで続行するため、受け入れるかどうかはサーバーが決めます。コールバックがない場合、Android はリクエストを
キャンセルし、iOS はシステムの既定処理になります。Android は応答をホストとポートごとに WebView の存続中記憶し、再度は
尋ねないため、応答を変えるには新しいコントローラが必要です。ファイルとパスワードはセキュアストレージに置き、アプリの
バンドルやログには入れないでください。
