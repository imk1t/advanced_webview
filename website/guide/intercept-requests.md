# Intercepting requests

Serve a page, or any resource, from Dart instead of the network. Pass the URL schemes you want to
handle and a callback; the callback returns a response, or `null` to let the request through.

```dart
final controller = AdvancedWebViewController(
  interceptSchemes: ['app'],
  onInterceptRequest: (request) async {
    // request.url, request.method, request.headers, request.isMainFrame
    if (request.url == 'app://host/index.html') {
      return InterceptResponse.text('<h1>Served from Dart</h1>');
    }
    final bytes = await loadBytesFor(request.url);
    return InterceptResponse(body: bytes, mimeType: 'image/png');
  },
);

await controller.loadUrl('app://host/index.html');
```

`InterceptResponse` takes the body bytes, a `mimeType` (it may carry a `charset`), a `statusCode`
(default 200) and extra `headers`. `InterceptResponse.text` is a shortcut for UTF-8 text.

Give `interceptSchemes` and `onInterceptRequest` together. The callback is called for the page itself
and for every sub-resource it requests (scripts, images, `fetch`), so relative URLs inside a page
served from `app://host/` come back to the callback too. Request bodies are not available.

## Differences

- **iOS can only handle custom schemes.** WebKit does not let apps intercept `http`, `https`, `file`,
  `data` and the other built-in schemes, so those entries in `interceptSchemes` are ignored on iOS.
  Android can intercept every scheme, including `https`. To stay portable, use a custom scheme such
  as `app`.
- **`null` means different things.** On Android it loads the request from the network as usual. A
  custom scheme on iOS has no network behind it, so `null` (and an error thrown by the callback)
  fails the request with an unsupported-URL error.
- **Redirects.** Android does not accept the 300 to 399 status codes in a made-up response; such an
  answer is let through. Serve the final content directly instead.
- **Timeout.** Android waits at most about 10 seconds for the callback, then lets the request
  through. iOS waits as long as the callback takes.
- **Threads.** Neither platform blocks the UI thread. On Android, WebView asks on one of its own IO
  threads and that thread waits while Dart answers, so keep the callback quick. A slow callback delays
  only that one request.
- **Cross-origin access.** A page on one origin that fetches from another needs the usual CORS
  headers in `InterceptResponse.headers` (for example `Access-Control-Allow-Origin`).

See the [API mapping](./api-mapping) for the native APIs behind it.
