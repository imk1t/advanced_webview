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

## Callbacks

Pass callbacks to the constructor:

```dart
AdvancedWebViewController(
  onPageStarted: (url) {},
  onPageFinished: (url) {},
  onProgress: (progress) {},   // 0-100
  onTitleChanged: (title) {},
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
