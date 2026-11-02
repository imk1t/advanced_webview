# Controller and widget

## One controller, one WebView

`AdvancedWebViewController` creates the native WebView as soon as it is constructed, and
destroys it only when you call `dispose()`. The `AdvancedWebView` widget just displays the
WebView that the controller owns.

Because of this, removing the widget from the tree (switching tabs, pushing a route) does
not reset the page. Call `dispose()` when you no longer need the WebView.

```dart
final controller = AdvancedWebViewController()..loadUrl('https://flutter.dev');

// build
AdvancedWebView(controller: controller);

// When you no longer need it
await controller.dispose();
```

## Loading content

```dart
await controller.loadUrl('https://example.com', headers: {'X-Token': 'abc'});
await controller.loadHtmlString('<h1>Hello</h1>', baseUrl: 'https://example.com');

await controller.reload();
await controller.stopLoading();
if (await controller.canGoBack()) await controller.goBack();
if (await controller.canGoForward()) await controller.goForward();

final url = await controller.currentUrl();
final title = await controller.title();
```

## Screenshots

```dart
final png = await controller.takeScreenshot(); // Uint8List? (PNG)
```

Captures only the visible area, not the whole page. Returns `null` while the view has no size.

## Scrolling

```dart
await controller.scrollTo(0, 500);        // absolute, no animation
await controller.scrollBy(0, 100);        // relative
final offset = await controller.scrollPosition(); // Offset
```

Offsets are logical pixels on both platforms. To follow the scroll position, pass
`onScrollChanged: (offset) {}` to the constructor. It fires for every scroll step, so keep it cheap;
when it is not set, no scroll events cross the platform channel.

## Saving and restoring state

```dart
final state = await controller.saveState();     // Uint8List? (history + scroll position)
// ... later, for example after an app restart, on a new controller:
final restored = await controller.restoreState(state!); // false: unreadable, load normally
```

The bytes are opaque and platform specific (a marshalled `Bundle` on Android, the archived
`WKWebView.interactionState` on iOS). Restore them only on the same platform, and discard them when
`restoreState` returns `false`. `saveState` returns `null` when there is no history yet.

## Find in page

```dart
final result = await controller.findText('flutter');
// result.found; on Android also result.matchCount and result.activeMatchIndex.
await controller.findText('flutter');                 // same query: next match
await controller.findText('flutter', forward: false); // previous match
await controller.clearMatches();                      // remove the highlights
```

iOS reports only whether a match was found; `matchCount` and `activeMatchIndex` are `null` there.

## Callbacks

Pass callbacks to the constructor:

```dart
AdvancedWebViewController(
  onPageStarted: (url) {},
  onPageFinished: (url) {},
  onProgress: (progress) {},   // 0-100
  onTitleChanged: (title) {},
  onScrollChanged: (offset) {},
  onWebResourceError: (error) {
    // error.errorCode is platform specific:
    // WebViewClient.ERROR_* on Android, NSError.code on iOS.
  },
);
```

## File uploads

`<input type="file">` works on both platforms without any Dart code.

- **iOS** uses WebKit's built-in picker. Add `NSPhotoLibraryUsageDescription` and, if pages may
  capture photos or video, `NSCameraUsageDescription` / `NSMicrophoneUsageDescription` to your
  app's `Info.plist`.
- **Android** opens the system document picker (`FileChooserParams.createIntent()`). It needs a
  foreground Activity, which Flutter apps have. `capture` (camera) attributes are not handled
  specially.
