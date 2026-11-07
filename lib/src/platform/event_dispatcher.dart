import 'package:flutter/services.dart';

import 'messages.g.dart';

/// Receives native -> Dart events for one WebView, already demultiplexed.
abstract interface class WebViewEventListener {
  void onPageStarted(String url);
  void onPageFinished(String url);
  void onProgressChanged(int progress);
  void onTitleChanged(String? title);
  void onScrollChanged(double x, double y);
  void onLongPress(double x, double y);
  void onConsoleMessage(ConsoleMessageMessage message);
  void onFindResult(int activeMatchIndex, int numberOfMatches, bool isDone);
  void onFaviconChanged(String? url);
  void onEnterFullscreen();
  void onExitFullscreen();
  void onReceivedError(WebResourceErrorMessage error);
  void onReceivedHttpError(HttpErrorMessage error);
  Future<NavigationDecisionMessage> shouldOverrideUrlLoading(
    NavigationRequestMessage request,
  );
  void onJavaScriptMessage(String channelName, String message);
  void onNewWindowRequest(String url);
  void onInAppBrowserClosed();
  void onDownloadStart(DownloadRequestMessage request);
  Future<SslErrorDecisionMessage> onSslError(SslErrorMessage error);
  Future<HttpAuthCredentialsMessage?> onHttpAuthRequest(
    HttpAuthRequestMessage request,
  );
  Future<ClientCertResponseMessage> onClientCertRequest(
    ClientCertRequestMessage request,
  );
  Future<PermissionDecisionMessage> onPermissionRequest(
    PermissionRequestMessage request,
  );
  Future<JsDialogResultMessage> onJsDialog(JsDialogRequestMessage request);
  Future<InterceptResponseMessage?> onInterceptRequest(
    InterceptRequestMessage request,
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
  void onScrollChanged(int webViewId, double x, double y) =>
      _listeners[webViewId]?.onScrollChanged(x, y);

  @override
  void onFaviconChanged(int webViewId, String? url) =>
      _listeners[webViewId]?.onFaviconChanged(url);

  @override
  void onEnterFullscreen(int webViewId) =>
      _listeners[webViewId]?.onEnterFullscreen();

  @override
  void onExitFullscreen(int webViewId) =>
      _listeners[webViewId]?.onExitFullscreen();

  @override
  void onFindResult(
    int webViewId,
    int activeMatchIndex,
    int numberOfMatches,
    bool isDone,
  ) => _listeners[webViewId]?.onFindResult(
    activeMatchIndex,
    numberOfMatches,
    isDone,
  );

  @override
  void onLongPress(int webViewId, double x, double y) =>
      _listeners[webViewId]?.onLongPress(x, y);

  @override
  void onConsoleMessage(int webViewId, ConsoleMessageMessage message) =>
      _listeners[webViewId]?.onConsoleMessage(message);

  @override
  void onReceivedHttpError(int webViewId, HttpErrorMessage error) =>
      _listeners[webViewId]?.onReceivedHttpError(error);

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
  void onInAppBrowserClosed(int webViewId) =>
      _listeners[webViewId]?.onInAppBrowserClosed();

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
  Future<ClientCertResponseMessage> onClientCertRequest(
    int webViewId,
    ClientCertRequestMessage request,
  ) async {
    final listener = _listeners[webViewId];
    if (listener == null) {
      return ClientCertResponseMessage(action: ClientCertActionMessage.cancel);
    }
    return listener.onClientCertRequest(request);
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
  Future<InterceptResponseMessage?> onInterceptRequest(
    int webViewId,
    InterceptRequestMessage request,
  ) async => _listeners[webViewId]?.onInterceptRequest(request);

  @override
  Future<JsDialogResultMessage> onJsDialog(
    int webViewId,
    JsDialogRequestMessage request,
  ) async {
    final listener = _listeners[webViewId];
    if (listener == null) return JsDialogResultMessage(accepted: false);
    return listener.onJsDialog(request);
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
