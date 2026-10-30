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

::: tip 単一の情報源
このページは [`website/data/api-mapping.json`](https://github.com/imk1t/advanced_webview/blob/main/website/data/api-mapping.json) から生成しています。
公開 Dart API に項目がない、存在しない Dart API を指す項目がある、引用したネイティブ API が Kotlin / Swift の
ソースから消えている、のいずれかの場合は CI が失敗します。
:::

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
