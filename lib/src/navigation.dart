import 'dart:async';

import 'package:flutter/foundation.dart';

/// A main-frame navigation about to happen.
@immutable
class NavigationRequest {
  const NavigationRequest({required this.url, required this.isMainFrame});

  final String url;
  final bool isMainFrame;
}

enum NavigationDecision { navigate, prevent }

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
typedef WebResourceErrorCallback = void Function(WebResourceError error);
typedef NavigationRequestCallback = FutureOr<NavigationDecision> Function(
  NavigationRequest request,
);

/// Called with the URL a page asked to open in a new window.
typedef NewWindowCallback = void Function(String url);
typedef JavaScriptMessageCallback = void Function(String message);
