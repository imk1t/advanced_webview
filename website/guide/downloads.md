# Downloads

The WebView does not save files. When a page starts a download, `onDownloadStart` tells you what it
was and you decide what to do with it.

```dart
final controller = AdvancedWebViewController(
  onDownloadStart: (download) async {
    // download.url, download.suggestedFilename, download.mimeType, download.contentLength
    final cookies = await controller.getCookies(download.url);
    // Fetch download.url with your own HTTP client (sending the cookies), or open it
    // in the system browser.
  },
);
```

A download is reported when:

- a link points to a file the WebView cannot show (for example a ZIP), or the response has
  `Content-Disposition: attachment`;
- a link has the `download` attribute.

`contentLength` is `null` when the server did not say. Without a callback, downloads are left to the
platform default: nothing happens on either platform.

## Differences

- Android guesses `suggestedFilename` from the URL and `Content-Disposition`
  (`URLUtil.guessFileName`), so it is never empty. iOS passes the name WebKit suggests, which can be
  `null` for `download` links.
- `blob:` and `data:` URLs are passed through unchanged. They only exist inside the page, so they
  cannot be fetched from Dart; read them in the page (with a JavaScript handler or channel) instead.
- The WebView does not send its cookies or `User-Agent` for you. Read the cookies with
  [`getCookies`](./cookies) and set the `User-Agent` yourself if the server needs it.
