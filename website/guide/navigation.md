# Navigation

Use `onNavigationRequest` to allow or block a navigation:

```dart
final controller = AdvancedWebViewController(
  onNavigationRequest: (request) => request.url.startsWith('https://')
      ? NavigationDecision.navigate
      : NavigationDecision.prevent,
);
```

The callback may return a `Future<NavigationDecision>`.

## What is reported

Both platforms behave the same way:

- Only **main-frame** navigations are reported.
- Only navigations started by the page are reported: links, forms, `window.location` and
  redirects.
- Loads started by the controller (`loadUrl`, `loadHtmlString`, `reload`, `goBack`,
  `goForward`) are not reported.

::: warning Android
Android has to answer synchronously, so the plugin cancels the navigation, asks Dart, and
re-issues it if it is allowed. The re-issued request is a GET, so POST bodies and redirects
are not preserved.
:::

## New windows

`window.open` and links with `target="_blank"` ask for a new window. Handle them with
`onNewWindow`:

```dart
final controller = AdvancedWebViewController(
  onNewWindow: (url) => launchUrlString(url), // or open it in another controller
);
```

When `onNewWindow` is set, the WebView does not load the URL itself. Without it, the URL loads in
the same WebView on both platforms (and goes through `onNavigationRequest`). On Android the plugin
reads the URL from a temporary WebView that it destroys right away.
