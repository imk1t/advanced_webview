import 'package:flutter/services.dart';

import 'messages.g.dart';

/// Receives native -> Dart events for one WebView, already demultiplexed.
abstract interface class WebViewEventListener {
  void onPageStarted(String url);
  void onPageFinished(String url);
  void onProgressChanged(int progress);
  void onTitleChanged(String? title);
  void onReceivedError(WebResourceErrorMessage error);
  Future<NavigationDecisionMessage> shouldOverrideUrlLoading(
    NavigationRequestMessage request,
  );
  void onJavaScriptMessage(String channelName, String message);
  void onNewWindowRequest(String url);
  void onDownloadStart(DownloadRequestMessage request);
  Future<SslErrorDecisionMessage> onSslError(SslErrorMessage error);
  Future<HttpAuthCredentialsMessage?> onHttpAuthRequest(
    HttpAuthRequestMessage request,
  );
  Future<PermissionDecisionMessage> onPermissionRequest(
    PermissionRequestMessage request,
  );
  Future<String> onJavaScriptHandlerCall(String handlerName, String argsJson);
}

/// Single [AdvancedWebViewFlutterApi] implementation that routes every event to
/// the listener registered for its `webViewId`.
class WebViewEventDispatcher implements AdvancedWebViewFlutterApi {
  WebViewEventDispatcher({this.binaryMessenger});

  static final WebViewEventDispatcher instance = WebViewEventDispatcher();

  final BinaryMessenger? binaryMessenger;
  final Map<int, WebViewEventListener> _listeners = {};
  bool _isSetUp = false;

  void register(int webViewId, WebViewEventListener listener) {
    if (!_isSetUp) {
      AdvancedWebViewFlutterApi.setUp(this, binaryMessenger: binaryMessenger);
      _isSetUp = true;
    }
    _listeners[webViewId] = listener;
  }

  void unregister(int webViewId) => _listeners.remove(webViewId);

  @override
  void onPageStarted(int webViewId, String url) =>
      _listeners[webViewId]?.onPageStarted(url);

  @override
  void onPageFinished(int webViewId, String url) =>
      _listeners[webViewId]?.onPageFinished(url);

  @override
  void onProgressChanged(int webViewId, int progress) =>
      _listeners[webViewId]?.onProgressChanged(progress);

  @override
  void onTitleChanged(int webViewId, String? title) =>
      _listeners[webViewId]?.onTitleChanged(title);

  @override
  void onReceivedError(int webViewId, WebResourceErrorMessage error) =>
      _listeners[webViewId]?.onReceivedError(error);

  @override
  Future<NavigationDecisionMessage> shouldOverrideUrlLoading(
    int webViewId,
    NavigationRequestMessage request,
  ) async {
    final listener = _listeners[webViewId];
    if (listener == null) return NavigationDecisionMessage.navigate;
    return listener.shouldOverrideUrlLoading(request);
  }

  @override
  void onJavaScriptMessage(int webViewId, String channelName, String message) =>
      _listeners[webViewId]?.onJavaScriptMessage(channelName, message);

  @override
  void onNewWindowRequest(int webViewId, String url) =>
      _listeners[webViewId]?.onNewWindowRequest(url);

  @override
  void onDownloadStart(int webViewId, DownloadRequestMessage request) =>
      _listeners[webViewId]?.onDownloadStart(request);

  @override
  Future<SslErrorDecisionMessage> onSslError(
    int webViewId,
    SslErrorMessage error,
  ) async {
    final listener = _listeners[webViewId];
    if (listener == null) return SslErrorDecisionMessage.cancel;
    return listener.onSslError(error);
  }

  @override
  Future<HttpAuthCredentialsMessage?> onHttpAuthRequest(
    int webViewId,
    HttpAuthRequestMessage request,
  ) async => _listeners[webViewId]?.onHttpAuthRequest(request);

  @override
  Future<PermissionDecisionMessage> onPermissionRequest(
    int webViewId,
    PermissionRequestMessage request,
  ) async {
    final listener = _listeners[webViewId];
    if (listener == null) return PermissionDecisionMessage.deny;
    return listener.onPermissionRequest(request);
  }

  @override
  Future<String> onJavaScriptHandlerCall(
    int webViewId,
    String handlerName,
    String argsJson,
  ) async {
    final listener = _listeners[webViewId];
    if (listener == null) {
      throw StateError('WebView $webViewId is no longer registered');
    }
    return listener.onJavaScriptHandlerCall(handlerName, argsJson);
  }
}
