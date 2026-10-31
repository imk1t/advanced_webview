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

await controller.clearCookies();
```

`setCookie` の後にページを読み込む（または再読み込みする）と、その Cookie が送信されます。

## プラットフォーム差

- Cookie ストアは、Android ではアプリ内のすべての WebView で、iOS ではデフォルトのデータストアを
  使うすべての WebView で共有されます。
- Android の `getCookies` は `name` と `value` のみ返します（`CookieManager.getCookie` が
  `name=value` の一覧を返すため）。`domain` は URL のホスト、`path` は `/`、フラグは `false` です。
  iOS はすべての属性を返します。
