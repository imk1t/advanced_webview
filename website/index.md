---
layout: page
sidebar: false
aside: false
title: advanced_webview
---

<AwHero
  eyebrow="Flutter · Android · iOS"
  title="A lean WebView for Flutter,"
  accent="built to stay maintainable."
  lead="One controller, one widget, immutable settings. A typed Dart API with identical behaviour on Android and iOS."
>
  <template #actions>
    <AwButton href="/guide/getting-started">Get started</AwButton>
    <AwButton href="https://github.com/imk1t/advanced_webview" variant="secondary">View on GitHub</AwButton>
  </template>
</AwHero>

<AwSection flush>
  <AwGrid>
    <AwFeature title="Android and iOS only">No Web or desktop targets. Two platforms, kept behaviourally identical.</AwFeature>
    <AwFeature title="Small public API">A controller, a widget and immutable settings. The controller owns the WebView, so it survives widget rebuilds.</AwFeature>
    <AwFeature title="Practical features">JavaScript channels, navigation control, cookies, user scripts, popups and file selection.</AwFeature>
  </AwGrid>
</AwSection>

<AwSection flush>
<AwCodePanel>

::: code-group

```dart [controller.dart]
final controller = AdvancedWebViewController(
  onPageFinished: (url) => debugPrint('loaded $url'),
)..loadUrl('https://flutter.dev');

// In build():
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
// In the page: window.app.postMessage('hello')
```

:::

</AwCodePanel>
</AwSection>

<AwSection title="One typed API, two platforms" lead="Same calls, same results on Android and iOS." flush>
  <AwGrid :cols="2">
    <AwCard title="Navigation control" art="accent" href="/guide/navigation" cta="Read the guide">Decide every main-frame request before it loads.</AwCard>
    <AwCard title="JavaScript channels" art="accent-2" href="/guide/javascript" cta="Read the guide">Call <code>window.name.postMessage(String)</code> from the page, on both platforms.</AwCard>
  </AwGrid>
</AwSection>

<AwSection title="Keep reading" flush>
  <AwGrid>
    <AwCard title="Getting started" href="/guide/getting-started" cta="Read the guide">Install the package and show your first page.</AwCard>
    <AwCard title="Platform API mapping" href="/guide/api-mapping" cta="Browse the table">Each Dart API next to the native Android and iOS API behind it.</AwCard>
    <AwCard title="Changelog" href="https://github.com/imk1t/advanced_webview/blob/main/CHANGELOG.md" cta="See releases">What changed in each release.</AwCard>
  </AwGrid>
</AwSection>

<AwCta title="Ship a WebView you can maintain" lead="Add advanced_webview to your app in a minute.">
  <template #actions>
    <AwButton href="/guide/getting-started" variant="inverse">Get started</AwButton>
    <AwButton href="https://pub.dev/packages/advanced_webview" variant="inverse-outline">pub.dev</AwButton>
  </template>
</AwCta>
