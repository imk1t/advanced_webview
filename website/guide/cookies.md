# Cookies

Read and write the WebView's cookies through the controller:

```dart
await controller.setCookie(
  const WebViewCookie(
    name: 'session',
    value: 'abc123',
    domain: 'example.com',
    isSecure: true,
    isHttpOnly: true,
    // expires: DateTime.now().add(const Duration(days: 7)), // omit for a session cookie
  ),
);

final cookies = await controller.getCookies('https://example.com/');

await controller.deleteCookie('https://example.com/', 'session'); // one cookie by name
await controller.deleteCookies('https://example.com/'); // every cookie sent to that URL
await controller.clearCookies(); // everything
```

Load or reload a page after `setCookie` for the cookie to be sent.

## Clearing website data

Cookies are one kind of website data. To clear the HTTP cache, `localStorage` / `sessionStorage` and
IndexedDB, use `clearWebsiteData`:

```dart
await controller.clearWebsiteData(); // cache, local storage and IndexedDB
await controller.clearWebsiteData(types: {WebsiteDataType.cache});
```

It does not remove cookies; call `clearCookies` for those. The data is shared, so it is cleared for
every WebView of the app on Android and for every WebView on the same data store on iOS. Android
cannot clear `localStorage` and IndexedDB separately: selecting either one clears all DOM storage of
the app. Pages that are already loaded keep what they hold in memory until they reload.

## Platform differences

- `deleteCookie` and `deleteCookies` remove what the WebView would send to the URL. iOS deletes exactly the
  cookies `getCookies` reports. Android cannot see a cookie's domain or path, so it expires the cookie for the
  host, its parent domains and every path from `/` down to the URL's path; a cookie stored for a deeper path than
  the URL stays. Pass the URL of the page that set the cookie.

- The cookie store is shared by all WebViews of the app on Android, and by all WebViews that use
  the default data store on iOS.
- On Android `getCookies` only reports `name` and `value` (`CookieManager.getCookie` returns a
  `name=value` list). `domain` is the host of the URL, `path` is `/`, and the flags are `false`.
  iOS reports every attribute.
