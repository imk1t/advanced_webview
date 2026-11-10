# Cookie

コントローラ経由で WebView の Cookie を読み書きできます。

```dart
await controller.setCookie(
  const WebViewCookie(
    name: 'session',
    value: 'abc123',
    domain: 'example.com',
    isSecure: true,
    isHttpOnly: true,
    // expires: DateTime.now().add(const Duration(days: 7)), // 省略するとセッション Cookie
  ),
);

final cookies = await controller.getCookies('https://example.com/');

await controller.deleteCookie('https://example.com/', 'session'); // 名前を指定して 1 件削除
await controller.deleteCookies('https://example.com/'); // その URL に送信されるすべての Cookie を削除
await controller.clearCookies(); // すべて削除
```

`setCookie` の後にページを読み込む（または再読み込みする）と、その Cookie が送信されます。

## ウェブサイトデータの削除

Cookie はウェブサイトデータの一種です。HTTP キャッシュ、`localStorage` / `sessionStorage`、IndexedDB を
削除するには `clearWebsiteData` を使います。

```dart
await controller.clearWebsiteData(); // キャッシュ、ローカルストレージ、IndexedDB
await controller.clearWebsiteData(types: {WebsiteDataType.cache});
```

Cookie は削除されないため、削除するには `clearCookies` を呼びます。データは共有されているため、Android では
アプリ内のすべての WebView、iOS では同じデータストアを使うすべての WebView から削除されます。Android は
`localStorage` と IndexedDB を個別に削除できず、どちらを選んでもアプリの DOM ストレージをすべて削除します。
読み込み済みのページは、再読み込みするまでメモリ上の内容を保持します。

## プラットフォーム差

- `deleteCookie` と `deleteCookies` は、WebView がその URL に送信する Cookie を削除します。iOS は `getCookies` が返す
  Cookie をそのまま削除します。Android は Cookie のドメインとパスを取得できないため、ホスト・親ドメイン・`/` から
  URL のパスまでのすべてのパスについて期限切れの Cookie を設定します。URL より深いパスに保存された Cookie は残ります。
  Cookie を設定したページの URL を渡してください。
- Cookie ストアは、Android ではアプリ内のすべての WebView で、iOS ではデフォルトのデータストアを
  使うすべての WebView で共有されます。
- Android の `getCookies` は `name` と `value` のみ返します（`CookieManager.getCookie` が
  `name=value` の一覧を返すため）。`domain` は URL のホスト、`path` は `/`、フラグは `false` です。
  iOS はすべての属性を返します。
