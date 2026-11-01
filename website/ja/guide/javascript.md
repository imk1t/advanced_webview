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

## JavaScript ハンドラ

ハンドラを使うと、ページから Dart を呼び出して値を受け取れます。コントローラの作成時に登録します。

```dart
final controller = AdvancedWebViewController(
  javaScriptHandlers: {
    'sum': (args) => args.fold<num>(0, (a, b) => a + (b as num)),
    'user': (args) async => {'name': await loadUserName(args.first as String)},
  },
);
```

ページ側は `window.advancedWebView.callHandler(name, ...args)` を呼びます。戻り値は Promise です。

```js
const total = await window.advancedWebView.callHandler('sum', 1, 2, 3); // 6
const user = await window.advancedWebView.callHandler('user', 'abc'); // { name: ... }
```

引数と結果は JSON（`null`、`bool`、`num`、`String`、`List`、`Map`）です。Dart のハンドラが例外を投げた場合や、
その名前のハンドラがない場合は、メッセージを持つ `Error` で Promise が reject されます。
`window.advancedWebView` は、ハンドラを 1 つ以上登録したときだけ存在します。

Android では `WEB_MESSAGE_LISTENER` と `DOCUMENT_START_SCRIPT` に対応した WebView が必要です（現行端末のシステム WebView は対応しています）。
対応していない場合、コントローラの作成が失敗します。

## ユーザースクリプト

ユーザースクリプトは、WebView が読み込むすべてのページに、DOM の解析前または解析後に注入されます。

```dart
final controller = AdvancedWebViewController(
  userScripts: const [
    UserScript(source: 'window.isApp = true;'), // ページ自身のスクリプトより前
    UserScript(
      source: 'document.body.classList.add("in-app");',
      injectionTime: UserScriptInjectionTime.atDocumentEnd, // DOMContentLoaded 後
    ),
  ],
);

await controller.addUserScript(const UserScript(source: '...'));
await controller.removeAllUserScripts();
```

スクリプトは追加後に読み込むページにのみ作用します。`mainFrameOnly` の既定値は `true` です。

Android では `DOCUMENT_START_SCRIPT` に対応した WebView が必要です（現行端末のシステム WebView は対応しています）。
`mainFrameOnly` と `atDocumentEnd` が iOS と同じ動きになるよう、プラグインがソースをラップします。

## チャネルの信頼境界 {#channel-trust-boundary}

チャネルは iframe を含む全フレームに公開されます。Android は `addJavascriptInterface` を使い、
iOS のチャネル shim は `forMainFrameOnly: false` で注入されます。
Dart に届くのはチャネル名と文字列メッセージで、送信元 origin やフレーム情報は含まれません。
`UserScript.mainFrameOnly` はユーザースクリプトだけの設定で、チャネルの公開範囲は制限しません。

ハンドラも同じ信頼境界です。`window.advancedWebView` は全フレームで使え、Dart に届くのはハンドラ名と引数だけで、
送信元の origin やフレーム情報は含まれません。

チャネルまたはハンドラを持つ WebView には、iframe を含め信頼できるコンテンツだけを読み込んでください。
メッセージの形式と要求された操作を検証し、認証情報の返却や権限の強い操作をメッセージだけで許可しないでください。
JavaScript は既定で有効です。不要な場合は `javaScriptEnabled: false` を使用し、チャネルの登録を省いてください。
ナビゲーション判定にも [制約](./navigation#セキュリティ上の境界)があります。
