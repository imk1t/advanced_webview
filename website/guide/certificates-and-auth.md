# Certificates and HTTP authentication

By default the WebView refuses pages with a bad certificate, cancels HTTP authentication and does not present
a client certificate. Three callbacks let the app take over.

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

## Client certificates (mutual TLS)

```dart
final controller = AdvancedWebViewController(
  onClientCertRequest: (request) async {
    // request.host, request.port, request.realm (iOS only)
    final p12 = await loadMyPkcs12(); // a Uint8List, for example from secure storage
    return ClientCertResponse.proceed(pkcs12: p12, password: 'secret');
    // or: const ClientCertResponse.cancel()  - fail the connection
    // or: const ClientCertResponse.ignore()  - continue without a certificate
  },
);
```

When a server asks for a client certificate, answer with the identity stored in a PKCS#12 (`.p12` / `.pfx`)
file and its password. The first key entry of the file is used with its certificate chain. A file that
cannot be read, a wrong password or an error thrown by the callback cancels the request. Prefer a 3DES or
AES encrypted file: very old or very new PKCS#12 encodings are not read by every OS version.

`ignore` continues without a certificate, so the server decides whether that is acceptable. Without a
callback, Android cancels the request and iOS uses the system default handling. Android remembers the answer
per host and port for the lifetime of the WebView and does not ask again, so a new answer needs a new
controller. Keep the file and its password in secure storage, never in the app bundle or in logs.
