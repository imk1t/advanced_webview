import 'package:flutter/foundation.dart';

import 'platform/messages.g.dart';

/// An HTTP cookie stored by the WebView.
@immutable
class WebViewCookie {
  const WebViewCookie({
    required this.name,
    required this.value,
    required this.domain,
    this.path = '/',
    this.expires,
    this.isSecure = false,
    this.isHttpOnly = false,
  });

  /// @nodoc
  @internal
  factory WebViewCookie.fromMessage(CookieMessage message) => WebViewCookie(
    name: message.name,
    value: message.value,
    domain: message.domain,
    path: message.path,
    expires: message.expiresMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(message.expiresMillis!),
    isSecure: message.isSecure,
    isHttpOnly: message.isHttpOnly,
  );

  /// The cookie name.
  final String name;

  /// The cookie value.
  final String value;

  /// The host the cookie belongs to, for example `example.com`.
  final String domain;

  /// The URL path the cookie is sent for. Defaults to `/`.
  final String path;

  /// When the cookie expires, or `null` for a session cookie.
  final DateTime? expires;

  /// Whether the cookie is only sent over HTTPS.
  final bool isSecure;

  /// Whether the cookie is hidden from JavaScript (`document.cookie`).
  final bool isHttpOnly;

  /// @nodoc
  @internal
  CookieMessage toMessage() => CookieMessage(
    name: name,
    value: value,
    domain: domain,
    path: path,
    isSecure: isSecure,
    isHttpOnly: isHttpOnly,
    expiresMillis: expires?.millisecondsSinceEpoch,
  );

  @override
  bool operator ==(Object other) =>
      other is WebViewCookie &&
      other.name == name &&
      other.value == value &&
      other.domain == domain &&
      other.path == path &&
      other.expires == expires &&
      other.isSecure == isSecure &&
      other.isHttpOnly == isHttpOnly;

  @override
  int get hashCode =>
      Object.hash(name, value, domain, path, expires, isSecure, isHttpOnly);

  @override
  String toString() =>
      'WebViewCookie($name=$value, domain: $domain, path: $path)';
}
