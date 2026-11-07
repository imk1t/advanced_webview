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

/// A server asking the client to present a certificate (mutual TLS).
@immutable
class ClientCertRequest {
  const ClientCertRequest({required this.host, required this.port, this.realm});

  final String host;
  final int port;

  /// The realm of the request. Only iOS reports one (and often `null`);
  /// always `null` on Android.
  final String? realm;

  @override
  String toString() => 'ClientCertRequest($host:$port, realm: $realm)';
}

/// What to do about a [ClientCertRequest].
enum ClientCertAction {
  /// Answer with the certificate and key of [ClientCertResponse.pkcs12].
  proceed,

  /// Refuse the request: the connection fails.
  cancel,

  /// Continue without a certificate. The server decides whether that is
  /// acceptable.
  ignore,
}

/// The answer to a [ClientCertRequest].
@immutable
class ClientCertResponse {
  /// Answers with the identity stored in a PKCS#12 (`.p12` / `.pfx`) file.
  ///
  /// The first key entry of the file is used, with its certificate chain.
  /// Data that cannot be read, or a wrong [password], cancels the request.
  const ClientCertResponse.proceed({
    required Uint8List this.pkcs12,
    required String this.password,
  }) : action = ClientCertAction.proceed;

  /// Refuses the request.
  const ClientCertResponse.cancel()
    : action = ClientCertAction.cancel,
      pkcs12 = null,
      password = null;

  /// Continues without a certificate.
  const ClientCertResponse.ignore()
    : action = ClientCertAction.ignore,
      pkcs12 = null,
      password = null;

  final ClientCertAction action;

  /// The PKCS#12 file, for [ClientCertAction.proceed].
  final Uint8List? pkcs12;

  /// The password of [pkcs12], for [ClientCertAction.proceed].
  final String? password;
}

/// Decides how to answer a client certificate request.
typedef ClientCertCallback = FutureOr<ClientCertResponse> Function(
  ClientCertRequest request,
);
