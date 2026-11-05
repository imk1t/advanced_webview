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

The following rules apply, subject to the Android limitations below:

- Only **main-frame** navigations are reported.
- Only navigations started by the page are reported: links, GET forms, `window.location` and
  redirects.
- Loads started by the controller (`loadUrl`, `loadHtmlString`, `reload`, `goBack`,
  `goForward`) are not reported.

::: warning Android
Android has to answer synchronously, so the plugin cancels the navigation, asks Dart, and
re-issues it if it is allowed. The re-issued request is a GET, so the original redirect flow and request metadata may change.
:::

## Load errors and HTTP errors

`onWebResourceError` reports loads that failed (no connection, bad host, TLS failure). A server that
answers with a 404 or 503 is not a failed load: the WebView shows the page the server sent. Use
`onHttpError` to find out about those:

```dart
final controller = AdvancedWebViewController(
  onHttpError: (error) {
    if (error.isMainFrame && error.statusCode >= 500) showRetryBanner(error.url);
  },
);
```

It is called for statuses of 400 and more. Android also reports sub-resources such as images and
scripts (`isMainFrame` is `false`). iOS reports the main page and iframes only, because WebKit does
not expose the status of sub-resources.

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

## Security boundary

Android's `shouldOverrideUrlLoading` is not called for POST requests, so POST form submissions
are outside `onNavigationRequest`. Its coverage differs from iOS. Subframe navigations and
subresource requests are also outside this delegate's control.
On both platforms, an exception from the Dart decision callback or a platform-channel error
allows the navigation. There is no timeout for a callback Future that never completes.

This delegate is not a complete network firewall. Validate the scheme and host before app-initiated
loads such as `loadUrl`, and validate `onNewWindow` URLs before handling them. When using JavaScript
channels, restrict content, including iframes, to sources you trust.
See the [channel trust boundary](./javascript#channel-trust-boundary).
