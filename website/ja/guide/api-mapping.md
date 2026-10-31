---
aside: false
---

# ネイティブ API 対応表

`advanced_webview` の公開 Dart API と、それが内部で使うネイティブの Android / iOS API の対応表です。
挙動やプラットフォーム差を Android・Apple の公式ドキュメントで調べるときや、機能がどちらの OS で使えるかを
確認するときに使います。

| 状態 | 意味 |
| --- | --- |
| 対応 | その OS で動作します。 |
| 一部対応 | 注記のとおり差異があります。 |
| 作成時のみ | ネイティブビューの作成時に読まれ、`updateSettings` では無視されます。 |
| 非対応 | その OS では効果がありません。 |


## ライフサイクルとウィジェット

<ApiMapping group="lifecycle" />

## 読み込みと履歴

<ApiMapping group="loading" />

## JavaScript

<ApiMapping group="javascript" />

## イベントとナビゲーション

<ApiMapping group="events" />

## 設定

<ApiMapping group="settings" />

## Cookie

<ApiMapping group="cookies" />

## ユーザースクリプト

<ApiMapping group="userScripts" />
