import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// A main-frame navigation about to happen.
@immutable
class NavigationRequest {
  const NavigationRequest({required this.url, required this.isMainFrame});

  final String url;
  final bool isMainFrame;
}

enum NavigationDecision { navigate, prevent }

/// A server answered a request with an HTTP error status (400 or more).
///
/// Unlike a [WebResourceError], the load itself worked: the WebView shows
/// whatever page the server sent with the error.
@immutable
class HttpError {
  const HttpError({
    required this.url,
    required this.statusCode,
    required this.isMainFrame,
  });

  final String url;

  /// The HTTP status code, for example 404 or 503.
  final int statusCode;

  /// Whether the response is for the page itself rather than a frame or (on
  /// Android) a sub-resource.
  final bool isMainFrame;

  @override
  String toString() => 'HttpError($statusCode, $url, mainFrame: $isMainFrame)';
}

/// A load error reported by the native WebView.
@immutable
class WebResourceError {
  const WebResourceError({
    required this.errorCode,
    required this.message,
    required this.isMainFrame,
    this.url,
  });

  /// Platform specific: `WebViewClient.ERROR_*` on Android, `NSError.code` on iOS.
  final int errorCode;
  final String message;
  final bool isMainFrame;
  final String? url;

  @override
  String toString() => 'WebResourceError($errorCode, $message, url: $url)';
}

typedef PageEventCallback = void Function(String url);
typedef ProgressCallback = void Function(int progress);
typedef TitleChangedCallback = void Function(String? title);

/// Reports the favicon URL of a page, or `null` when it has none.
typedef FaviconChangedCallback = void Function(String? url);
typedef LongPressCallback = void Function(Offset offset);
typedef ScrollChangedCallback = void Function(Offset offset);
typedef WebResourceErrorCallback = void Function(WebResourceError error);
typedef HttpErrorCallback = void Function(HttpError error);
typedef NavigationRequestCallback = FutureOr<NavigationDecision> Function(
  NavigationRequest request,
);

/// Called with the URL a page asked to open in a new window.
typedef NewWindowCallback = void Function(String url);
typedef JavaScriptMessageCallback = void Function(String message);

/// Handles a call from `window.advanced_webview.callHandler(name, ...args)`.
///
/// [arguments] holds the JSON-decoded arguments the page passed. The returned
/// value must be JSON-encodable (`null`, `bool`, `num`, `String`, `List` or
/// `Map`); it resolves the page's promise. Throwing rejects the promise with
/// an `Error` carrying the exception text.
typedef JavaScriptHandler = FutureOr<Object?> Function(List<Object?> arguments);
