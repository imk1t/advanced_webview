# Settings

`WebViewSettings` is immutable. Pass it to the constructor, or replace it later with
`updateSettings`:

```dart
final controller = AdvancedWebViewController(
  settings: const WebViewSettings(userAgent: 'MyApp/1.0'),
);

await controller.updateSettings(const WebViewSettings(javaScriptEnabled: false));
```

Options that exist on one platform only live in `AndroidWebViewSettings` and `IOSWebViewSettings`,
passed as `android:` and `ios:`. The other platform ignores them, so one `WebViewSettings` value works
on both:

```dart
const WebViewSettings(
  android: AndroidWebViewSettings(passkeysEnabled: true),
  ios: IOSWebViewSettings(allowsInlineMediaPlayback: true),
);
```


| Setting | Default | Android | iOS |
| --- | --- | --- | --- |
| `javaScriptEnabled` | `true` | Yes | Yes |
| `mediaPlaybackRequiresUserGesture` | `true` | Yes | Creation only |
| `transparentBackground` | `false` | Yes | Yes |
| `inspectable` | `false` | Yes (process-wide) | Yes |
| `textZoom` | `100` | Text only | Whole page |
| `cacheMode` | `normal` | Yes | `loadUrl` only |
| `javaScriptCanOpenWindowsAutomatically` | `true` | Yes | Yes |
| `scrollbarsVisible` | `true` | Yes | Yes |
| `overScrollEnabled` | `true` | Yes | Yes |
| `pullToRefreshEnabled` | `false` | Yes | Yes (needs `overScrollEnabled`) |
| `minimumFontSize` | `null` (platform default) | Yes | Yes |
| `userAgent` | `null` (platform default) | Yes | Yes |

## Android-only settings

Passed as `WebViewSettings.android`. iOS ignores all of them.

| Setting | Default | Android | iOS |
| --- | --- | --- | --- |
| `supportZoom` | `true` | Yes | Ignored |
| `passkeysEnabled` | `false` | Yes | Ignored (see below) |
| `domStorageEnabled` | `true` | Yes | Ignored (always on) |
| `allowFileAccess` | `false` | Yes | Ignored |
| `allowContentAccess` | `false` | Yes | Ignored |
| `mixedContentMode` | `neverAllow` | Yes | Ignored (WebKit blocks it) |
| `geolocationEnabled` | `true` | Yes | Ignored (system decides) |

## iOS-only settings

Passed as `WebViewSettings.ios`. Android ignores all of them.

| Setting | Default | Android | iOS |
| --- | --- | --- | --- |
| `allowsInlineMediaPlayback` | `false` | Ignored | Creation only |
| `allowsBackForwardNavigationGestures` | `false` | Ignored | Yes |
| `incognito` | `false` | Ignored | Creation only |
| `applicationNameForUserAgent` | `null` | Ignored | Creation only |
| `contentMode` | `recommended` | Ignored | Yes |
| `allowsLinkPreview` | `true` | Ignored | Yes |

"Creation only" settings are applied when the native view is created and ignored by
`updateSettings` on that platform.

## Android security settings

`AndroidWebViewSettings.allowFileAccess`, `allowContentAccess` and `mixedContentMode` default to the restrictive values, so a page
cannot read local files or `content://` providers and HTTP content is blocked on HTTPS pages. Loosen them
only for content you control. `mixedContentMode: alwaysAllow` lets a network attacker tamper with secure
pages. iOS has no equivalent settings: WebKit blocks mixed content and there is no file access switch.
`domStorageEnabled` stays on by default, as in earlier versions.

## Passkeys (WebAuthn)

Passkeys work only for sites whose domain is associated with your app.

- **Android:** set `AndroidWebViewSettings.passkeysEnabled: true` and publish `/.well-known/assetlinks.json` with
  `delegate_permission/common.get_login_creds`, your package name and signing certificate
  SHA-256. Requires `androidx.webkit` 1.12+ and a WebView that supports WebAuthn; otherwise the
  setting is ignored.
- **iOS (16+):** no setting is needed. Add the Associated Domains capability with
  `webcredentials:example.com` and serve `/.well-known/apple-app-site-association` with your app ID.
- Passkeys of third-party identity providers (e.g. Google) and `mediation: "conditional"` are not
  supported inside a WebView.

See [Platform API mapping](./api-mapping#settings) for the native API behind each setting.

On Android, `updateSettings` can enable and disable passkeys on a WebView that supports WebAuthn.
