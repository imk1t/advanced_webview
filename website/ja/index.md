---
layout: home

hero:
  name: flutter_mobile_webview
  text: Android と iOS に絞った Flutter の WebView
  tagline: Pigeon ベースの、小さく型安全な WebView プラグイン。
  actions:
    - theme: brand
      text: はじめる
      link: /ja/guide/getting-started
    - theme: alt
      text: GitHub
      link: https://github.com/imk1t/flutter_mobile_webview

features:
  - title: Android と iOS のみ
    details: Web やデスクトップは対象外。2つのプラットフォームの振る舞いを揃えることに集中しています。
  - title: 型安全なプラットフォーム契約
    details: Dart・Kotlin・Swift 間の呼び出しはすべて1つの Pigeon ファイルで定義。MethodChannel の文字列を手書きしません。
  - title: 小さな公開 API
    details: コントローラ、ウィジェット、不変の設定だけ。WebView の寿命はコントローラが持つので、ウィジェットを作り直しても状態が残ります。
---
