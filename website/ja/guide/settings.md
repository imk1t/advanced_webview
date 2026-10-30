# 設定

`WebViewSettings` は不変オブジェクトです。コンストラクタで渡すか、後から `updateSettings` で置き換えます。

```dart
final controller = AdvancedWebViewController(
  settings: const WebViewSettings(userAgent: 'MyApp/1.0'),
);

await controller.updateSettings(const WebViewSettings(javaScriptEnabled: false));
```

| 設定 | 既定値 | Android | iOS |
| --- | --- | --- | --- |
| `javaScriptEnabled` | `true` | 対応 | 対応 |
| `mediaPlaybackRequiresUserGesture` | `true` | 対応 | 生成時のみ |
| `allowsInlineMediaPlayback` | `false` | 無視 | 生成時のみ |
| `supportZoom` | `true` | 対応 | 無視 |
| `transparentBackground` | `false` | 対応 | 対応 |
| `userAgent` | `null`（プラットフォーム既定） | 対応 | 対応 |

「生成時のみ」の設定はネイティブビューの生成時に適用され、そのプラットフォームでは `updateSettings` で変更しても無視されます。
