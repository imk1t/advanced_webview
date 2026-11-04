# Certificates and HTTP authentication

By default the WebView refuses pages with a bad certificate and cancels HTTP authentication. Two
callbacks let the app take over.

## Certificate errors

```dart
final controller = AdvancedWebViewController(
  onSslError: (error) {
    // error.host, error.url, error.message
    return error.host == 'dev.example.test'
        ? SslErrorDecision.proceed
        : SslErrorDecision.cancel;
  },
);
```

`onSslError` is called for an expired, not yet valid, mismatched or untrusted certificate, for the page
and for its sub-resources. `SslErrorDecision.proceed` loads anyway and **removes the protection TLS gives
the user**. Use it for a certificate you know, such as a development server, never for a general
"ignore errors" switch. Without a callback, and when the callback throws, the load is refused on both
platforms.

The `message` wording is platform specific; do not parse it.

## HTTP authentication

```dart
var attempts = 0;
final controller = AdvancedWebViewController(
  onHttpAuthRequest: (request) {
    // request.host, request.realm
    if (++attempts > 3) return null; // give up instead of asking forever
    return const HttpAuthCredentials(username: 'user', password: 'secret');
  },
);
```

Return the credentials, or `null` to cancel. HTTP Basic, Digest and NTLM are handled. The server asks again
when the credentials are wrong, so stop after a few attempts. Without a callback the request is
cancelled on Android and gets the system default handling on iOS, which fails the request as well. Proxy
authentication on iOS is left to the system.

Credentials are held for the session by the system, not stored by the plugin. Keep them out of logs
and do not hard-code real ones.
