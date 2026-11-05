import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// A request to a URL scheme listed in
/// [AdvancedWebViewController.interceptSchemes].
///
/// Request bodies are not available on either platform.
@immutable
class InterceptedRequest {
  const InterceptedRequest({
    required this.url,
    required this.method,
    required this.headers,
    required this.isMainFrame,
  });

  /// The requested URL.
  final String url;

  /// The HTTP method, upper-case (`GET`, `POST`, ...).
  final String method;

  /// The request headers the WebView would send.
  final Map<String, String> headers;

  /// Whether the request loads the top-level page (as opposed to a
  /// sub-resource or an iframe).
  final bool isMainFrame;

  @override
  String toString() => 'InterceptedRequest($method $url)';
}

/// A response made up by the app for an [InterceptedRequest].
@immutable
class InterceptResponse {
  const InterceptResponse({
    required this.body,
    this.mimeType = 'application/octet-stream',
    this.statusCode = 200,
    this.headers = const {},
  });

  /// A UTF-8 text response, `text/html` by default.
  factory InterceptResponse.text(
    String text, {
    String mimeType = 'text/html',
    int statusCode = 200,
    Map<String, String> headers = const {},
  }) => InterceptResponse(
    body: Uint8List.fromList(utf8.encode(text)),
    mimeType: '$mimeType; charset=utf-8',
    statusCode: statusCode,
    headers: headers,
  );

  /// The response body.
  final Uint8List body;

  /// The `Content-Type`, optionally with a `charset` parameter.
  final String mimeType;

  /// The HTTP status. Android rejects the redirect range (300 to 399).
  final int statusCode;

  /// Extra response headers. `Content-Type` is taken from [mimeType].
  final Map<String, String> headers;

  @override
  String toString() =>
      'InterceptResponse($statusCode, $mimeType, '
      '${body.length} bytes)';
}

/// Answers an [InterceptedRequest]. Return `null` to let it through.
///
/// An error thrown by the callback counts as `null`.
typedef InterceptRequestCallback = FutureOr<InterceptResponse?> Function(
  InterceptedRequest request,
);
