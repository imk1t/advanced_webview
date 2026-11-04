# 設定

`WebViewSettings` は不変オブジェクトです。コンストラクタで渡すか、後から `updateSettings` で置き換えます。

```dart
final controller = AdvancedWebViewController(
  settings: const WebViewSettings(userAgent: 'MyApp/1.0'),
);

await controller.updateSettings(const WebViewSettings(javaScriptEnabled: false));
```

片方の OS にしかないオプションは `AndroidWebViewSettings` と `IOSWebViewSettings` にあり、`android:` と
`ios:` で渡します。もう一方の OS では無視されるので、同じ `WebViewSettings` を両方で使えます。

```dart
const WebViewSettings(
  android: AndroidWebViewSettings(passkeysEnabled: true),
  ios: IOSWebViewSettings(allowsInlineMediaPlayback: true),
);
```


| 設定 | 既定値 | Android | iOS |
| --- | --- | --- | --- |
| `javaScriptEnabled` | `true` | 対応 | 対応 |
| `mediaPlaybackRequiresUserGesture` | `true` | 対応 | 生成時のみ |
| `transparentBackground` | `false` | 対応 | 対応 |
| `inspectable` | `false` | 対応（プロセス全体） | 対応 |
| `textZoom` | `100` | 文字のみ | ページ全体 |
| `cacheMode` | `normal` | 対応 | `loadUrl` のみ |
| `javaScriptCanOpenWindowsAutomatically` | `true` | 対応 | 対応 |
| `scrollbarsVisible` | `true` | 対応 | 対応 |
| `overScrollEnabled` | `true` | 対応 | 対応 |
| `pullToRefreshEnabled` | `false` | 対応 | 対応（`overScrollEnabled` が必要） |
| `minimumFontSize` | `null`（プラットフォーム既定） | 対応 | 対応 |
| `userAgent` | `null`（プラットフォーム既定） | 対応 | 対応 |

## Android 専用の設定

`WebViewSettings.android` に渡します。iOS ではすべて無視されます。

| 設定 | 既定値 | Android | iOS |
| --- | --- | --- | --- |
| `supportZoom` | `true` | 対応 | 無視 |
| `passkeysEnabled` | `false` | 対応 | 無視（下記参照） |
| `domStorageEnabled` | `true` | 対応 | 無視（常に有効） |
| `allowFileAccess` | `false` | 対応 | 無視 |
| `allowContentAccess` | `false` | 対応 | 無視 |
| `mixedContentMode` | `neverAllow` | 対応 | 無視（WebKit が遮断） |

## iOS 専用の設定

`WebViewSettings.ios` に渡します。Android ではすべて無視されます。

| 設定 | 既定値 | Android | iOS |
| --- | --- | --- | --- |
| `allowsInlineMediaPlayback` | `false` | 無視 | 生成時のみ |
| `allowsBackForwardNavigationGestures` | `false` | 無視 | 対応 |
| `incognito` | `false` | 無視 | 生成時のみ |
| `applicationNameForUserAgent` | `null` | 無視 | 生成時のみ |

「生成時のみ」の設定はネイティブビューの生成時に適用され、そのプラットフォームでは `updateSettings` で変更しても無視されます。

## Android のセキュリティ設定

`AndroidWebViewSettings` の `allowFileAccess`・`allowContentAccess`・`mixedContentMode` の既定値は制限的な側です。ページはローカルファイルや
`content://` プロバイダーを読めず、HTTPS ページ上の HTTP コンテンツは遮断されます。緩めるのは自分が管理する
コンテンツに限ってください。`mixedContentMode: alwaysAllow` はネットワーク上の攻撃者に安全なページを改ざんされる
恐れがあります。iOS には同等の設定がありません（WebKit が混在コンテンツを遮断し、ファイルアクセスの切り替えもありません）。
`domStorageEnabled` は従来どおり既定で有効です。

## パスキー（WebAuthn） {#passkeys-webauthn}

パスキーは、ドメインがアプリと関連付けられたサイトでのみ使えます。

- **Android:** `passkeysEnabled: true` を指定し、`/.well-known/assetlinks.json` に
  `delegate_permission/common.get_login_creds`、パッケージ名、署名証明書の SHA-256 を記載します。
  `androidx.webkit` 1.12 以上と WebAuthn 対応の WebView が必要で、非対応なら設定は無視されます。
- **iOS（16 以上）:** 設定は不要です。Associated Domains capability に `webcredentials:example.com`
  を追加し、`/.well-known/apple-app-site-association` にアプリ ID を記載します。
- 外部 IdP（Google など）のパスキーと `mediation: "conditional"` は WebView 内では使えません。

各設定が使うネイティブ API は[ネイティブ API 対応表](./api-mapping#設定)を参照してください。

Android の WebAuthn 対応 WebView では、`updateSettings` でパスキーを有効・無効に切り替えられます。
