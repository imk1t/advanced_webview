import 'dart:async';

import 'package:flutter/foundation.dart';

/// A TLS certificate problem the WebView found while loading a page or one of
/// its resources.
@immutable
class SslError {
  const SslError({
    required this.url,
    required this.host,
    required this.message,
  });

  /// The URL being loaded when the problem was found.
  final String url;

  final String host;

  /// A description of the problem. The wording is platform specific.
  final String message;

  @override
  String toString() => 'SslError($host, $message, url: $url)';
}

enum SslErrorDecision {
  /// Load the page despite the certificate problem. This disables the
  /// protection TLS gives the user, so use it only for a certificate you
  /// know, such as a development server.
  proceed,

  /// Refuse to load. This is what happens without a callback.
  cancel,
}

/// Decides what to do about a certificate problem.
typedef SslErrorCallback = FutureOr<SslErrorDecision> Function(SslError error);

/// A server asking for a user name and password (HTTP Basic, Digest or NTLM).
@immutable
class HttpAuthRequest {
  const HttpAuthRequest({required this.host, this.realm});

  final String host;

  /// The realm the server named, when it named one.
  final String? realm;

  @override
  String toString() => 'HttpAuthRequest($host, realm: $realm)';
}

/// A user name and password for an [HttpAuthRequest].
@immutable
class HttpAuthCredentials {
  const HttpAuthCredentials({required this.username, required this.password});

  final String username;
  final String password;
}

/// Returns the credentials for [request], or `null` to cancel the request.
///
/// The server may ask again if the credentials are wrong, so give up
/// (return `null`) after a few attempts instead of answering forever.
typedef HttpAuthCallback = FutureOr<HttpAuthCredentials?> Function(
  HttpAuthRequest request,
);
