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

// A Flutter asset from `flutter: assets:` in pubspec.yaml
await controller.loadFlutterAsset('assets/web/index.html');

// A file on the device
await controller.loadFile('/path/to/page.html');

// A POST request
await controller.loadRequest(
  'https://example.com/login',
  method: WebViewHttpMethod.post,
  body: Uint8List.fromList(utf8.encode('user=a&pass=b')),
);

await controller.reload();
await controller.stopLoading();
if (await controller.canGoBack()) await controller.goBack();
if (await controller.canGoForward()) await controller.goForward();

final url = await controller.currentUrl();
final title = await controller.title();
```

Platform notes for the three newer loaders:

- `loadFlutterAsset`: relative links resolve to sibling assets. Android serves them from
  `https://appassets.androidplatform.net/assets/flutter_assets/...` and does not need
  `allowFileAccess`; a missing asset loads as a 404 (see `onHttpError`). iOS loads the file from the
  app bundle with read access to its folder and throws `not-found` for a missing asset.
- `loadFile`: Android needs `AndroidWebViewSettings.allowFileAccess` (off by default), otherwise it
  throws `file-access-disabled`. iOS throws `not-found` for a missing file.
- `loadRequest`: Android sends a POST body as `application/x-www-form-urlencoded` and cannot add
  headers to a POST (it throws `unsupported` when you pass some). iOS sends the headers and body as
  given. A `body` is only allowed with `WebViewHttpMethod.post`.

## Screenshots

```dart
final png = await controller.takeScreenshot(); // Uint8List? (PNG)
```

Captures only the visible area, not the whole page. Returns `null` while the view has no size.

## PDF export

```dart
final pdf = await controller.createPdf(); // Uint8List (PDF bytes)
```

Wait for the page to finish loading first. Android lays the content out on A4 pages the way printing
does, so the page's print styles apply. iOS returns a single page as tall as the whole content with the
screen styles. A failure throws a `PlatformException` with code `pdf-failed`.

## Scrolling

```dart
await controller.scrollTo(0, 500);        // absolute, no animation
await controller.scrollBy(0, 100);        // relative
final offset = await controller.scrollPosition(); // Offset
```

Offsets are logical pixels on both platforms. To follow the scroll position, pass
`onScrollChanged: (offset) {}` to the constructor. It fires for every scroll step, so keep it cheap;
when it is not set, no scroll events cross the platform channel.

## Pause and resume

```dart
await controller.pause();   // for example while another screen covers the WebView
await controller.resume();
await controller.pauseTimers();  // Android only, affects every WebView in the app
await controller.resumeTimers();
```

Android pauses what `WebView.onPause` pauses (animations, geolocation, plugins); JavaScript timers keep running
until `pauseTimers`, which applies to **all** WebViews of the app. iOS has no general pause, so `pause` suspends the
playback of every audio and video element, and `pauseTimers` / `resumeTimers` do nothing. After `resume` on iOS,
media that was playing stays paused until the page plays it again.

## Zoom

```dart
await controller.zoomBy(1.5);           // multiply the current scale
await controller.setZoomScale(2);       // set the scale
final scale = await controller.getZoomScale(); // double
```

The scale is in logical pixels per CSS pixel: `1.0` shows one CSS pixel as one logical pixel. A page without a
viewport `<meta>` tag usually starts below `1.0`. Both platforms keep the result within the page's zoom limits, so a
page with `user-scalable=no` ignores these calls. On Android the settings `supportZoom` and `builtInZoomControls`
must be on (they are by default); Android has no absolute setter, so `setZoomScale` zooms by the ratio to the current
scale and can be slightly off. Android also ignores zoom calls until the page has been drawn, so a call right after the page finished loading can be lost. iOS zooms the scroll view (`UIScrollView.zoomScale`); `WKWebView.pageZoom` stays with
`textZoom`, so the two do not interfere.

## Saving and restoring state

```dart
final state = await controller.saveState();     // Uint8List? (history + scroll position)
// ... later, for example after an app restart, on a new controller:
final restored = await controller.restoreState(state!); // false: unreadable, load normally
```

The bytes are opaque and platform specific (a marshalled `Bundle` on Android, the archived
`WKWebView.interactionState` on iOS). Restore them only on the same platform, and discard them when
`restoreState` returns `false`. `saveState` returns `null` when there is no history yet.

## Printing

```dart
await controller.printPage(jobName: 'Invoice');
```

Opens the system print dialog (`PrintManager` on Android, `UIPrintInteractionController` on iOS) and
returns once it is presented. The WebView has to be shown in an `AdvancedWebView`; otherwise the call
throws a `PlatformException` with code `not-attached`.

## Long press and hit testing

```dart
AdvancedWebViewController(
  onLongPress: (position) async {
    final hit = await controller.hitTest(position);
    // hit.type: none, link, image or imageLink; hit.linkUrl / hit.imageUrl
  },
);
```

`onLongPress` reports the touch position in logical pixels relative to the WebView, and the platform's own
long-press behaviour (text selection, link menu) still happens. `hitTest` looks the position up with
`document.elementFromPoint`, so it only sees the main frame and works the same on both platforms. Use it
to build a custom context menu.

## Console messages

```dart
AdvancedWebViewController(
  onConsoleMessage: (message) {
    debugPrint('[${message.level.name}] ${message.message}');
  },
);
```

`onConsoleMessage` reports every `console.debug`, `log`, `info`, `warn` and `error` call the page makes, in any
frame, and the platform's own console output (Logcat, Web Inspector) still happens. Uncaught exceptions and
browser-generated messages are not reported. Android passes the script URL and line number as
`sourceUrl` / `lineNumber`; iOS has no such information, so they are `null` there (WebKit has no console callback,
so a script injected at document start wraps the `console` methods). Android may deliver `console.info` as
`log`. Use it together with `WebViewSettings.inspectable` when debugging a page.

## Find in page

```dart
final result = await controller.findText('flutter');
// result.found, result.matchCount and result.activeMatchIndex.
await controller.findText('flutter');                 // same query: next match
await controller.findText('flutter', forward: false); // previous match
await controller.clearMatches();                      // remove the highlights
```

To keep a "3 of 12" label in sync, pass `onFindResult` to the constructor. It receives the active match
index, the number of matches so far and whether the count is final:

```dart
AdvancedWebViewController(
  onFindResult: (activeMatchIndex, numberOfMatches, isDone) {
    setState(() => label = '${activeMatchIndex + 1} / $numberOfMatches');
  },
);
```

Android reports every update while WebView counts (`isDone` is `false` until the last one). iOS sends one final
update per `findText` call. WebKit does not report a count or a position, so on iOS the plugin counts the
query in the page text and follows the search direction to keep the index. Both are best-effort and can
differ from the highlights for text WebKit searches differently, for example inside iframes.

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

## Favicon and fullscreen

```dart
AdvancedWebViewController(
  onFaviconChanged: (url) {}, // after each page finishes loading; String?
  onEnterFullscreen: () {},   // hide your own chrome
  onExitFullscreen: () {},
);
```

`onFaviconChanged` gives the URL of the page's `<link rel="icon">` (or `/favicon.ico` on its origin when the page
declares none, which may not exist) and `null` for non-HTTP pages. WebKit has no public favicon API and Android only
hands over decoded bitmaps, so both platforms read the page's markup, which gives the same answer on each. Load the
image yourself, for example with `Image.network`. Icons added by a script after the page finished loading are not
reported.

Fullscreen is shown by the platform; the callbacks only report it. A video's fullscreen button and
`element.requestFullscreen()` both work. On Android the plugin covers the Activity's window with the content, hides
the system bars and leaves fullscreen when the user presses back. It does not rotate the screen, so set the
orientation yourself in `onEnterFullscreen` if you want landscape. Before this release Android did not offer
fullscreen at all. iOS presents WebKit's own fullscreen view and the plugin enables the element fullscreen API for it.

## Renderer crashes

```dart
AdvancedWebViewController(
  onRenderProcessGone: (details) {
    // details.didCrash: true / false on Android, null on iOS
  },
);
```

The process that renders web content can crash or be killed by the system, for example under memory pressure.
On iOS the view turns blank and `controller.reload()` brings the page back. On Android the plugin handles the event so
the app is not terminated, but that WebView cannot be used any more: dispose the controller and create a new one
(with a new `AdvancedWebView`). Without the callback, Android does the same silently.

## File uploads

`<input type="file">` works on both platforms without any Dart code.

- **iOS** uses WebKit's built-in picker. Add `NSPhotoLibraryUsageDescription` and, if pages may
  capture photos or video, `NSCameraUsageDescription` / `NSMicrophoneUsageDescription` to your
  app's `Info.plist`.
- **Android** opens the system document picker (`FileChooserParams.createIntent()`). It needs a
  foreground Activity, which Flutter apps have. `capture` (camera) attributes are not handled
  specially.
