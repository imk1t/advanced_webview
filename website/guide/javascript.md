# JavaScript

## Running JavaScript

```dart
// Ignore the result
await controller.runJavaScript('document.body.style.background = "red"');

// The result is JSON-encoded natively and decoded in Dart:
// null, bool, num, String, List or Map. `undefined` becomes null.
final title = await controller.runJavaScriptReturningResult('document.title');
```

## JavaScript channels

Channels send messages from the page to Dart. Register them when you create the controller:

```dart
final controller = AdvancedWebViewController(
  javaScriptChannels: {'Bridge': (message) => print(message)},
);
```

On both platforms the page calls the same API:

```js
window.Bridge.postMessage('hello');
```

Messages are strings. Use `JSON.stringify` on the JavaScript side if you need to send
structured data.
