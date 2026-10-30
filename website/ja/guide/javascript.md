# JavaScript

## JavaScript の実行

```dart
// 戻り値を使わない
await controller.runJavaScript('document.body.style.background = "red"');

// 戻り値はネイティブで JSON 化され、Dart でデコードされます:
// null, bool, num, String, List, Map。`undefined` は null になります。
final title = await controller.runJavaScriptReturningResult('document.title');
```

## JavaScript チャネル

チャネルはページから Dart へメッセージを送ります。コントローラの生成時に登録します。

```dart
final controller = AdvancedWebViewController(
  javaScriptChannels: {'Bridge': (message) => print(message)},
);
```

ページ側は両 OS で同じ API を呼びます。

```js
window.Bridge.postMessage('hello');
```

メッセージは文字列です。構造化データを送るときは JavaScript 側で `JSON.stringify` してください。
