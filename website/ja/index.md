---
layout: page
sidebar: false
aside: false
title: advanced_webview
---

<AwHero
  eyebrow="Flutter · Android · iOS"
  title="シンプルに使えて、"
  accent="必要な機能はひととおり。"
  lead="コントローラとウィジェットだけで始められます。ナビゲーション、JavaScript、Cookie、ダウンロード、権限などの機能も、必要なときに同じ API で使えます。Android と iOS で動きも揃っています。"
>
  <template #actions>
    <AwButton href="/ja/guide/getting-started">はじめる</AwButton>
    <AwButton href="https://github.com/imk1t/advanced_webview" variant="secondary">GitHub</AwButton>
  </template>
</AwHero>

<AwSection flush>
  <AwGrid>
    <AwFeature title="Android と iOS のみ">Web やデスクトップは対象外。2つのプラットフォームの振る舞いを揃えることに集中しています。</AwFeature>
    <AwFeature title="小さな公開 API">コントローラ、ウィジェット、不変の設定だけ。WebView の寿命はコントローラが持つので、ウィジェットを作り直しても状態が残ります。</AwFeature>
    <AwFeature title="実用的な機能">JavaScript チャンネル、ナビゲーション制御、リクエストのインターセプト、クライアント証明書、ズーム操作、ダークモード、システムブラウザ、Cookie、ユーザースクリプト、ポップアップ、PDF 書き出し、ファイル選択。</AwFeature>
  </AwGrid>
</AwSection>

<AwSection flush>
<AwCodePanel>

::: code-group

```dart [controller.dart]
final controller = AdvancedWebViewController(
  onPageFinished: (url) => debugPrint('loaded $url'),
)..loadUrl('https://flutter.dev');

// build() 内:
AdvancedWebView(controller: controller)
```

```dart [navigation.dart]
final controller = AdvancedWebViewController(
  onNavigationRequest: (request) =>
      request.url.startsWith('https://')
          ? NavigationDecision.navigate
          : NavigationDecision.prevent,
);
```

```dart [channels.dart]
final controller = AdvancedWebViewController(
  javaScriptChannels: {
    'app': (message) => debugPrint('from JS: $message'),
  },
);
// ページ側: window.app.postMessage('hello')
```

:::

</AwCodePanel>
</AwSection>

<AwSection title="1つの型付き API で、2つのプラットフォーム" lead="Android でも iOS でも、同じ呼び出しで同じ結果になります。" flush>
  <AwGrid :cols="2">
    <AwCard title="ナビゲーション制御" art="accent" href="/ja/guide/navigation" cta="ガイドを読む">メインフレームのリクエストを、読み込み前に1件ずつ判断できます。</AwCard>
    <AwCard title="JavaScript チャンネル" art="accent-2" href="/ja/guide/javascript" cta="ガイドを読む">ページから <code>window.name.postMessage(String)</code> を呼べます。両プラットフォームで共通です。</AwCard>
  </AwGrid>
</AwSection>

<AwSection title="次に読む" flush>
  <AwGrid>
    <AwCard title="はじめに" href="/ja/guide/getting-started" cta="ガイドを読む">パッケージを追加して、最初のページを表示します。</AwCard>
    <AwCard title="ネイティブ API 対応表" href="/ja/guide/api-mapping" cta="表を見る">各 Dart API と、その裏で呼ばれる Android / iOS の API を並べています。</AwCard>
    <AwCard title="変更履歴" href="https://github.com/imk1t/advanced_webview/blob/main/CHANGELOG.md" cta="リリースを見る">各リリースの変更点です。</AwCard>
  </AwGrid>
</AwSection>

<AwCta title="Flutter アプリに WebView を追加する" lead="advanced_webview を入れて、1分で最初のページを表示できます。">
  <template #actions>
    <AwButton href="/ja/guide/getting-started" variant="inverse">はじめる</AwButton>
    <AwButton href="https://pub.dev/packages/advanced_webview" variant="inverse-outline">pub.dev</AwButton>
  </template>
</AwCta>
