# ダウンロード

WebView はファイルを保存しません。ページがダウンロードを始めると `onDownloadStart` で内容が通知されるので、
その後の処理はアプリ側で決めます。

```dart
final controller = AdvancedWebViewController(
  onDownloadStart: (download) async {
    // download.url, download.suggestedFilename, download.mimeType, download.contentLength
    final cookies = await controller.getCookies(download.url);
    // download.url を自前の HTTP クライアントで（Cookie を付けて）取得するか、
    // システムのブラウザで開きます。
  },
);
```

次の場合にダウンロードとして通知されます。

- WebView が表示できないファイル（ZIP など）へのリンク、または `Content-Disposition: attachment` のレスポンス
- `download` 属性を持つリンク

`contentLength` はサーバーが示さなかった場合 `null` です。コールバックがない場合はプラットフォームの既定動作のままで、
どちらの OS でも何も起こりません。

## 違い

- Android は URL と `Content-Disposition` から `suggestedFilename` を推測する（`URLUtil.guessFileName`）ため、空にはなりません。
  iOS は WebKit が提案する名前を渡すため、`download` リンクでは `null` になることがあります。
- `blob:` と `data:` の URL はそのまま渡されます。ページの中にしか存在しないため Dart からは取得できません。
  ページ側で読み取り、JavaScript ハンドラやチャネルで渡してください。
- WebView の Cookie と `User-Agent` は自動では付きません。Cookie は [`getCookies`](./cookies) で取得し、
  サーバーが必要とするなら `User-Agent` も自分で設定してください。
