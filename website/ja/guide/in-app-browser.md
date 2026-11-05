# アプリ内ブラウザ

`AdvancedInAppBrowser` は、ツールバー付きの全画面ネイティブブラウザを Flutter の UI の上に開きます。
自前の画面から離れたいが、アプリからは出したくないリンクに使います。

```dart
final browser = AdvancedInAppBrowser(
  onOpened: () => debugPrint('opened'),
  onClosed: () => debugPrint('closed'),
  onPageFinished: (url) => debugPrint('loaded $url'),
  onLoadError: (error) => debugPrint('failed: $error'),
);

await browser.open(
  Uri.parse('https://example.com'),
  options: const InAppBrowserOptions(
    toolbarColor: Color(0xFF1E3A8A),
    showUrl: true,
  ),
);

// あとで:
await browser.close();
```

## オプション

| オプション | 既定値 | 意味 |
| --- | --- | --- |
| `toolbarColor` | プラットフォーム既定 | ツールバーの背景色。タイトルとボタンは読みやすいように黒か白になります。 |
| `toolbarTitle` | ページのタイトル | 現在のページのタイトルの代わりに表示する固定タイトル。 |
| `showUrl` | `false` | タイトルの下に現在の URL を表示します。 |
| `showNavigationButtons` | `true` | 戻る・進む・再読み込みのボタンを表示します。 |
| `closeButtonLabel` | アイコン | プラットフォームの閉じるアイコンの代わりに使うテキスト。 |
| `settings` | `WebViewSettings()` | ブラウザ内 WebView の設定（`android:` / `ios:` を含む）。 |

## 動作

- 1つの `AdvancedInAppBrowser` が同時に表示できるブラウザは1つです。開いている間の `open` は
  `StateError` を投げます。`onClosed` のあとは再度開けます。
- ブラウザは専用の WebView を持ちます。開いている間は `loadUrl` と `evaluateJavaScript` が使え、
  閉じている間は `StateError` になります。
- `onLoadError` はメインページの失敗だけを通知し、画像やスクリプトの失敗は通知しません。
- 表示できる画面がない場合（アプリがバックグラウンドのときなど）、`open` は
  `PlatformException`（`not-attached`）で失敗します。

## 違い

- Android は専用の `Activity` を表示します。戻るボタンはまずページ履歴を戻り、戻れないときにブラウザを閉じます。
  権限ダイアログとファイル選択はブラウザの前面に表示されます。
- iOS は `UINavigationController` をモーダルで表示します。戻る・進む・再読み込みは下部のツールバー、
  閉じるボタンはナビゲーションバーの左側にあります。
- Android では Cookie が他の WebView と共有されます。iOS では `WebViewSettings.incognito` で
  ブラウザのウェブサイトデータを分離できます。

内部で使うネイティブ API は [プラットフォーム API 対応表](./api-mapping#アプリ内ブラウザ) を参照してください。
