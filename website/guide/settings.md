# Settings

`WebViewSettings` is immutable. Pass it to the constructor, or replace it later with
`updateSettings`:

```dart
final controller = AdvancedWebViewController(
  settings: const WebViewSettings(userAgent: 'MyApp/1.0'),
);

await controller.updateSettings(const WebViewSettings(javaScriptEnabled: false));
```

| Setting | Default | Android | iOS |
| --- | --- | --- | --- |
| `javaScriptEnabled` | `true` | Yes | Yes |
| `mediaPlaybackRequiresUserGesture` | `true` | Yes | Creation only |
| `allowsInlineMediaPlayback` | `false` | Ignored | Creation only |
| `supportZoom` | `true` | Yes | Ignored |
| `transparentBackground` | `false` | Yes | Yes |
| `userAgent` | `null` (platform default) | Yes | Yes |

"Creation only" settings are applied when the native view is created and ignored by
`updateSettings` on that platform.

See [Platform API mapping](./api-mapping#settings) for the native API behind each setting.
