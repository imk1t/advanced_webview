# In-app browser

`AdvancedInAppBrowser` opens a page in a full-screen native browser with a toolbar, over your Flutter
UI. Use it for links that should leave your own screens without leaving the app.

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

// Later:
await browser.close();
```

## Options

| Option | Default | Meaning |
| --- | --- | --- |
| `toolbarColor` | platform | Background of the toolbar. Title and buttons switch between black and white to stay readable. |
| `toolbarTitle` | page title | Fixed title instead of the title of the current page. |
| `showUrl` | `false` | Shows the current URL under the title. |
| `showNavigationButtons` | `true` | Shows back, forward and reload buttons. |
| `closeButtonLabel` | icon | Text for the close button instead of the platform's close icon. |
| `settings` | `WebViewSettings()` | Settings of the WebView in the browser, including `android:` and `ios:`. |

## Behaviour

- One `AdvancedInAppBrowser` shows one browser at a time. `open` throws a `StateError` while it is
  open; after `onClosed` you can open it again.
- The browser has its own WebView. Use `loadUrl` and `evaluateJavaScript` on the browser while it is
  open; both throw a `StateError` otherwise.
- `onLoadError` reports main-page failures only, not failed images or scripts.
- `open` fails with a `PlatformException` (`not-attached`) when the app has no screen to present
  from, for example while it is in the background.

## Differences

- Android shows a dedicated `Activity`. The back button goes back in the page first and closes the
  browser when there is nothing to go back to. Permission prompts and file choosers are handled by
  the main Activity, so they may appear behind the browser on some devices.
- iOS presents a `UINavigationController` modally. The back, forward and reload buttons are in a
  bottom toolbar, and the close button is on the left of the navigation bar.
- Cookies are shared with other WebViews on Android. On iOS, set `WebViewSettings.incognito` to
  isolate the browser's website data.

See [Platform API mapping](./api-mapping#in-app-browser) for the native APIs behind it.
