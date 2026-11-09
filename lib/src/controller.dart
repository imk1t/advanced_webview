import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'console_message.dart';
import 'cookie.dart';
import 'download.dart';
import 'find.dart';
import 'hit_test.dart';
import 'intercept.dart';
import 'js_dialog.dart';
import 'load_request.dart';
import 'navigation.dart';
import 'permission.dart';
import 'platform/event_dispatcher.dart';
import 'platform/messages.g.dart';
import 'security.dart';
import 'settings.dart';
import 'user_script.dart';
import 'website_data.dart';

/// Controls one native WebView.
///
/// The native view is created as soon as the controller is constructed and
/// lives until [dispose] is called, independently of the [AdvancedWebView]
/// widget.
class AdvancedWebViewController {
  AdvancedWebViewController({
    WebViewSettings settings = const WebViewSettings(),
    Map<String, JavaScriptMessageCallback> javaScriptChannels = const {},
    Map<String, JavaScriptHandler> javaScriptHandlers = const {},
    String javaScriptHandlerObjectName = 'advanced_webview',
    List<UserScript> userScripts = const [],
    List<String> interceptSchemes = const [],
    this.onInterceptRequest,
    this.onPageStarted,
    this.onPageFinished,
    this.onProgress,
    this.onTitleChanged,
    this.onScrollChanged,
    this.onLongPress,
    this.onConsoleMessage,
    this.onWebResourceError,
    this.onHttpError,
    this.onRenderProcessGone,
    this.onFindResult,
    this.onFaviconChanged,
    this.onEnterFullscreen,
    this.onExitFullscreen,
    this.onNavigationRequest,
    this.onNewWindow,
    this.onPermissionRequest,
    this.onJsDialog,
    this.onDownloadStart,
    this.onSslError,
    this.onHttpAuthRequest,
    this.onClientCertRequest,
    @visibleForTesting AdvancedWebViewHostApi? hostApi,
    @visibleForTesting WebViewEventDispatcher? dispatcher,
  }) : webViewId = _nextWebViewId++,
       _settings = settings,
       _javaScriptChannels = Map.unmodifiable(javaScriptChannels),
       _javaScriptHandlers = Map.unmodifiable(javaScriptHandlers),
       _hostApi = hostApi ?? AdvancedWebViewHostApi(),
       _dispatcher = dispatcher ?? WebViewEventDispatcher.instance {
    final schemes = _normalizeSchemes(interceptSchemes, onInterceptRequest);
    if (!_identifier.hasMatch(javaScriptHandlerObjectName)) {
      throw ArgumentError.value(
        javaScriptHandlerObjectName,
        'javaScriptHandlerObjectName',
        'must be a valid JavaScript identifier',
      );
    }
    _interceptSchemes = schemes;
    _dispatcher.register(webViewId, _EventListener(this));
    _created = _hostApi.create(
      CreationParamsMessage(
        webViewId: webViewId,
        settings: settings.toMessage(),
        javaScriptChannelNames: _javaScriptChannels.keys.toList(),
        javaScriptHandlerNames: _javaScriptHandlers.keys.toList(),
        javaScriptHandlerObjectName: javaScriptHandlerObjectName,
        hasNavigationDelegate: onNavigationRequest != null,
        hasNewWindowDelegate: onNewWindow != null,
        hasPermissionDelegate: onPermissionRequest != null,
        hasDownloadDelegate: onDownloadStart != null,
        hasSslErrorDelegate: onSslError != null,
        hasHttpAuthDelegate: onHttpAuthRequest != null,
        hasClientCertDelegate: onClientCertRequest != null,
        hasScrollDelegate: onScrollChanged != null,
        hasLongPressDelegate: onLongPress != null,
        hasConsoleMessageDelegate: onConsoleMessage != null,
        hasJsDialogDelegate: onJsDialog != null,
        hasHttpErrorDelegate: onHttpError != null,
        hasFindDelegate: onFindResult != null,
        hasFaviconDelegate: onFaviconChanged != null,
        hasFullscreenDelegate:
            onEnterFullscreen != null || onExitFullscreen != null,
        interceptSchemes: schemes,
        userScripts: [for (final script in userScripts) script.toMessage()],
      ),
    );
  }

  static int _nextWebViewId = 0;

  static final _scheme = RegExp(r'^[a-z][a-z0-9+.-]*$');

  static List<String> _normalizeSchemes(
    List<String> schemes,
    InterceptRequestCallback? callback,
  ) {
    if ((callback == null) != schemes.isEmpty) {
      throw ArgumentError(
        'onInterceptRequest and interceptSchemes must be given together',
      );
    }
    final result = {for (final scheme in schemes) scheme.toLowerCase()};
    for (final scheme in result) {
      if (!_scheme.hasMatch(scheme)) {
        throw ArgumentError.value(
          scheme,
          'interceptSchemes',
          'must be a valid URL scheme',
        );
      }
    }
    return result.toList();
  }

  static final _identifier = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$');

  /// Identifies this WebView across the platform channel.
  final int webViewId;

  final AdvancedWebViewHostApi _hostApi;
  final WebViewEventDispatcher _dispatcher;
  final Map<String, JavaScriptMessageCallback> _javaScriptChannels;
  final Map<String, JavaScriptHandler> _javaScriptHandlers;
  late final Future<void> _created;
  WebViewSettings _settings;
  bool _isDisposed = false;

  final PageEventCallback? onPageStarted;
  final PageEventCallback? onPageFinished;
  final ProgressCallback? onProgress;
  final TitleChangedCallback? onTitleChanged;

  /// Called after each page finishes loading with the URL of its favicon, or
  /// `null` when there is none. Load the image yourself, for example with
  /// `Image.network`.
  ///
  /// The URL comes from the page's `<link rel="icon">` (or `shortcut icon`);
  /// pages without one report `/favicon.ico` on their origin, which may not
  /// exist, and non-HTTP pages report `null`. WebKit has no public favicon API
  /// and Android only hands over decoded bitmaps, so both platforms read the
  /// page's markup instead, which gives the same answer on each. Icons that a
  /// script adds after the page finished loading are not reported.
  ///
  /// Android: `WebView.evaluateJavascript` after `WebViewClient.onPageFinished`.
  /// iOS: `WKWebView.evaluateJavaScript(_:completionHandler:)` after
  /// `WKNavigationDelegate.webView(_:didFinish:)`.
  final FaviconChangedCallback? onFaviconChanged;

  /// Called when the page enters fullscreen, for example when the user taps the
  /// fullscreen button of a `<video>` or the page calls
  /// `element.requestFullscreen()`. Hide your own chrome here.
  ///
  /// Both platforms show the fullscreen content themselves; these callbacks
  /// only report it. On Android the plugin covers the Activity's window with
  /// the content, hides the system bars and leaves fullscreen on back; it does
  /// not change the screen orientation, so rotate the app yourself if you want
  /// landscape. Without an Activity to show it in, Android refuses the
  /// request. iOS presents WebKit's fullscreen view (iOS enables the
  /// element fullscreen API for this).
  ///
  /// Android: `WebChromeClient.onShowCustomView`.
  /// iOS: key-value observing of `WKWebView.fullscreenState`.
  final VoidCallback? onEnterFullscreen;

  /// Called when the page leaves fullscreen. See [onEnterFullscreen].
  final VoidCallback? onExitFullscreen;

  /// Called whenever the page scrolls, with the new offset in logical pixels.
  ///
  /// Reported for every scroll step, so keep the callback cheap. Only set at
  /// construction: leaving it `null` keeps scroll events off the platform
  /// channel.
  final ScrollChangedCallback? onScrollChanged;

  /// Called when the user long-presses the page, with the touch position in
  /// logical pixels relative to the WebView. Pass it to [hitTest] to find out
  /// whether a link or image was pressed, for example to show a custom menu.
  ///
  /// The platform's own long-press behaviour (text selection, system link
  /// menu) still happens. Only set at construction.
  final LongPressCallback? onLongPress;

  /// Called for every `console.debug`, `log`, `info`, `warn` and `error` call
  /// the page makes, in any frame. Useful for debugging pages; combine with
  /// [WebViewSettings.inspectable] for full inspector access.
  ///
  /// The platform's own console handling still happens (Logcat on Android, the
  /// Web Inspector on iOS). Uncaught exceptions and browser-generated messages
  /// are not reported. Only set at construction: leaving it `null` keeps
  /// console output off the platform channel.
  ///
  /// Android: `WebChromeClient.onConsoleMessage(ConsoleMessage)`; the source
  /// URL and line number are reported, and `console.info` may arrive as
  /// [WebViewConsoleMessageLevel.log]. iOS: a user script injected at document
  /// start in every frame wraps the `console` methods and posts to a
  /// `WKScriptMessageHandler`; the source URL and line number are `null`.
  final ConsoleMessageCallback? onConsoleMessage;
  final WebResourceErrorCallback? onWebResourceError;

  /// Called when a server answers with an HTTP status of 400 or more. The
  /// WebView still shows the page the server sent; [onWebResourceError] is not
  /// called for these.
  ///
  /// Android reports the main page, frames and sub-resources
  /// (`HttpError.isMainFrame` tells them apart). iOS reports the main page and
  /// iframes only, because WebKit does not expose the status of sub-resources.
  /// Only set at construction: leaving it `null` keeps these events off the
  /// platform channel.
  ///
  /// Android: `WebViewClient.onReceivedHttpError(WebView, WebResourceRequest,
  /// WebResourceResponse)`. iOS:
  /// `WKNavigationDelegate.webView(_:decidePolicyFor:decisionHandler:)` for
  /// navigation responses, reading `HTTPURLResponse.statusCode`.
  final HttpErrorCallback? onHttpError;

  /// Called when the process that renders web content crashes or is killed
  /// by the system, for example under memory pressure.
  ///
  /// The page is gone and the WebView cannot show anything until you act.
  /// Android: the WebView can no longer be used, so dispose this controller
  /// and create a new one (and a new [AdvancedWebView]); the plugin handles
  /// the event so the app is not terminated, even without this callback.
  /// iOS: the view is blank; call [reload] to recover.
  ///
  /// Android: `WebViewClient.onRenderProcessGone(WebView, RenderProcessGoneDetail)`.
  /// iOS: `WKNavigationDelegate.webViewWebContentProcessDidTerminate(_:)`.
  final RenderProcessGoneCallback? onRenderProcessGone;

  /// Called for main-frame navigations started by the page (links, forms,
  /// `window.location`, redirects). Android does not report POST requests.
  /// Loads started by this controller
  /// ([loadUrl], [loadHtmlString], [reload], [goBack], [goForward]) are not
  /// reported. On Android an allowed navigation is re-issued as a GET, so the original
  /// redirect flow and request metadata may change. Callback or platform-channel
  /// errors allow navigation; this is not a complete network filter.
  final NavigationRequestCallback? onNavigationRequest;

  /// Called when the page asks for a new window (`window.open`, links with
  /// `target="_blank"`) with the URL it wants to open.
  ///
  /// When set, the WebView does not load the URL itself; open it wherever
  /// suits the app, for example in another controller or the system browser.
  /// When `null`, the URL loads in this WebView (and goes through
  /// [onNavigationRequest] like any page-initiated navigation).
  ///
  /// Android: `WebChromeClient.onCreateWindow(WebView, boolean, boolean, Message)`
  /// with `WebSettings.setSupportMultipleWindows(true)`; the URL is read from a
  /// temporary WebView that is destroyed right away.
  /// iOS: `WKUIDelegate.webView(_:createWebViewWith:for:windowFeatures:)`.
  final NewWindowCallback? onNewWindow;

  /// Called when the WebView finds a certificate problem (expired, untrusted
  /// or mismatched certificate) while loading a page or one of its resources.
  ///
  /// Return [SslErrorDecision.proceed] to load anyway, which disables TLS
  /// protection for that load: use it only for a certificate you know, such as
  /// a development server. Without a callback, and when the callback throws,
  /// the load is refused on both platforms.
  ///
  /// Android: `WebViewClient.onReceivedSslError(WebView, SslErrorHandler, SslError)`.
  /// iOS: `WKNavigationDelegate.webView(_:didReceive:completionHandler:)` for
  /// `NSURLAuthenticationMethodServerTrust`, after `SecTrustEvaluateWithError`
  /// failed.
  final SslErrorCallback? onSslError;

  /// Called when a server asks for a user name and password (HTTP Basic,
  /// Digest or NTLM).
  ///
  /// Return the credentials, or `null` to cancel. If the server rejects them
  /// it asks again, so return `null` after a few attempts. Without a callback
  /// the request is cancelled on Android and gets the system default handling
  /// on iOS, which also fails the request.
  ///
  /// Android: `WebViewClient.onReceivedHttpAuthRequest(WebView, HttpAuthHandler, String, String)`.
  /// iOS: `WKNavigationDelegate.webView(_:didReceive:completionHandler:)` for
  /// `NSURLAuthenticationMethodHTTPBasic`, `HTTPDigest` and `NTLM`.
  final HttpAuthCallback? onHttpAuthRequest;

  /// Called when a server asks for a client certificate (mutual TLS). Return
  /// [ClientCertResponse.proceed] with a PKCS#12 file to present your
  /// identity, [ClientCertResponse.cancel] to fail the connection, or
  /// [ClientCertResponse.ignore] to continue without a certificate.
  ///
  /// Without a callback, Android cancels the request and iOS uses the system
  /// default handling. Android remembers the answer for the host and port for
  /// the lifetime of the WebView and does not ask again. If the callback
  /// throws, the request is cancelled.
  ///
  /// Android: `WebViewClient.onReceivedClientCertRequest(WebView, ClientCertRequest)`.
  /// iOS: `WKNavigationDelegate.webView(_:didReceive:completionHandler:)` for
  /// `NSURLAuthenticationMethodClientCertificate`.
  final ClientCertCallback? onClientCertRequest;

  /// Called when the page starts a download: a link to a file the WebView
  /// cannot show, or a response with `Content-Disposition: attachment`.
  ///
  /// The WebView does not save the file; see [DownloadRequest] for how to
  /// fetch it. When `null`, downloads are left to the platform default, which
  /// does nothing on Android and shows nothing on iOS.
  ///
  /// Android: `WebView.setDownloadListener(DownloadListener)`; the file name is
  /// guessed with `URLUtil.guessFileName`.
  /// iOS: `WKNavigationDelegate.webView(_:decidePolicyFor:decisionHandler:)` for
  /// `WKNavigationResponse`; the navigation is cancelled.
  final DownloadStartCallback? onDownloadStart;

  /// Called when a page asks for camera, microphone or location access.
  ///
  /// Return [PermissionDecision.grant] to allow it. Without a callback every
  /// request is denied on both platforms. Errors in the callback deny the
  /// request.
  ///
  /// Granting only gives the *page* access. The app itself still needs the
  /// operating system permission: on Android, declare it in the manifest
  /// (`CAMERA`, `RECORD_AUDIO`, `ACCESS_FINE_LOCATION`) and the plugin asks the
  /// user at runtime when needed; the request is denied if the user refuses. On
  /// iOS add `NSCameraUsageDescription` / `NSMicrophoneUsageDescription` to
  /// `Info.plist`; WebKit shows the system prompt.
  ///
  /// [PermissionResource.geolocation] is Android only. On iOS, WebKit has no
  /// delegate for it and asks the user itself, based on the app's location
  /// permission (`NSLocationWhenInUseUsageDescription`).
  ///
  /// Android: `WebChromeClient.onPermissionRequest(PermissionRequest)` and
  /// `onGeolocationPermissionsShowPrompt(String, GeolocationPermissions.Callback)`.
  /// iOS: `WKUIDelegate.webView(_:requestMediaCapturePermissionFor:initiatedByFrame:type:decisionHandler:)`.
  final PermissionRequestCallback? onPermissionRequest;

  /// Called when the page opens a JavaScript dialog (`alert`, `confirm` or
  /// `prompt`). The page is blocked until the returned future completes, so
  /// answer promptly.
  ///
  /// Without a callback the platform shows its default dialog (on iOS the
  /// plugin presents a native alert). Errors in the
  /// callback dismiss the dialog (`confirm` returns `false`, `prompt` returns
  /// `null`). Dialogs from `beforeunload` are not reported.
  ///
  /// Android: `WebChromeClient.onJsAlert`, `onJsConfirm` and `onJsPrompt`.
  /// iOS: `WKUIDelegate.webView(_:runJavaScriptAlertPanelWithMessage:...)`,
  /// `runJavaScriptConfirmPanelWithMessage` and
  /// `runJavaScriptTextInputPanelWithPrompt`.
  final JsDialogCallback? onJsDialog;

  /// The URL schemes whose requests are passed to [onInterceptRequest], for
  /// example `['app']` to serve `app://index.html` from Dart. Matched
  /// case-insensitively; give it together with [onInterceptRequest].
  ///
  /// iOS can only intercept custom schemes, because WebKit does not let apps
  /// handle `http`, `https`, `file`, `data` and other built-in schemes; those
  /// entries are ignored there. Android intercepts any scheme, including
  /// `http` and `https`.
  List<String> get interceptSchemes => List.unmodifiable(_interceptSchemes);
  late final List<String> _interceptSchemes;

  /// Called for every request to one of [interceptSchemes], including the
  /// sub-resources of pages loaded from it. Return an [InterceptResponse] to
  /// answer the request yourself, or `null` to let it through.
  ///
  /// On iOS a custom scheme has no network behind it, so `null` (and an
  /// error) fails the request with an unsupported-URL error. On Android
  /// `null` loads the request from the network as usual. Requests are
  /// answered asynchronously without blocking the UI thread; Android waits at
  /// most about 10 seconds before letting the request through. Request bodies
  /// are not available.
  ///
  /// Android: `WebViewClient.shouldInterceptRequest`.
  /// iOS: `WKURLSchemeHandler` registered with
  /// `WKWebViewConfiguration.setURLSchemeHandler(_:forURLScheme:)`.
  final InterceptRequestCallback? onInterceptRequest;

  /// Completes once the native WebView exists.
  Future<void> get ready => _created;

  /// Called when the in-app browser showing this WebView is dismissed. Set by
  /// `AdvancedInAppBrowser`.
  @internal
  VoidCallback? onInAppBrowserClosed;

  /// Presents this WebView in the native in-app browser.
  @internal
  Future<void> openInAppBrowser(InAppBrowserParamsMessage params) =>
      _call(() => _hostApi.openInAppBrowser(params));

  /// Dismisses the native in-app browser; a no-op when it is not open.
  @internal
  Future<void> closeInAppBrowser() =>
      _call(() => _hostApi.closeInAppBrowser(webViewId));

  WebViewSettings get settings => _settings;

  bool get isDisposed => _isDisposed;

  Future<void> loadUrl(String url, {Map<String, String> headers = const {}}) =>
      _call(() => _hostApi.loadUrl(webViewId, url, headers));

  Future<void> loadHtmlString(String html, {String? baseUrl}) =>
      _call(() => _hostApi.loadHtmlString(webViewId, html, baseUrl));

  /// Loads [url] with the given [method].
  ///
  /// A [body] is only allowed with [WebViewHttpMethod.post]. On Android a POST
  /// is sent as `application/x-www-form-urlencoded` and [headers] must be empty
  /// (the platform cannot add headers to a POST), otherwise this throws a
  /// `PlatformException` with the code `unsupported`. iOS sends [headers] and
  /// the [body] as given.
  ///
  /// Android: `WebView.loadUrl(String, Map)` and `WebView.postUrl(String, byte[])`.
  /// iOS: `WKWebView.load(_:)` with a `URLRequest` carrying the method and body.
  Future<void> loadRequest(
    String url, {
    WebViewHttpMethod method = WebViewHttpMethod.get,
    Map<String, String> headers = const {},
    Uint8List? body,
  }) {
    if (body != null && method != WebViewHttpMethod.post) {
      throw ArgumentError.value(body, 'body', 'is only allowed with POST');
    }
    return _call(
      () => _hostApi.loadRequest(
        webViewId,
        url,
        switch (method) {
          WebViewHttpMethod.get => HttpMethodMessage.get,
          WebViewHttpMethod.post => HttpMethodMessage.post,
        },
        headers,
        body,
      ),
    );
  }

  /// Loads a Flutter asset declared under `flutter: assets:` in `pubspec.yaml`,
  /// for example `loadFlutterAsset('assets/web/index.html')`.
  ///
  /// Relative links in the page resolve to sibling assets. Android serves the
  /// asset from `https://appassets.androidplatform.net/assets/flutter_assets/...`
  /// and does not need `allowFileAccess`. iOS loads the file from the app bundle
  /// with read access to its folder. A missing asset throws on iOS; on Android
  /// the page loads as a 404 (see [onHttpError]).
  ///
  /// Android: `WebViewAssetLoader` with `AssetsPathHandler`.
  /// iOS: `WKWebView.loadFileURL(_:allowingReadAccessTo:)`.
  Future<void> loadFlutterAsset(String key) =>
      _call(() => _hostApi.loadFlutterAsset(webViewId, key));

  /// Loads the file at the absolute [path] on the device.
  ///
  /// On Android this needs [AndroidWebViewSettings.allowFileAccess] (off by
  /// default); without it this throws a `PlatformException` with the code
  /// `file-access-disabled`. iOS gives the page read access to the file's
  /// folder, and throws `not-found` when the file does not exist.
  ///
  /// Android: `WebView.loadUrl` with a `file://` URL. iOS:
  /// `WKWebView.loadFileURL(_:allowingReadAccessTo:)`.
  Future<void> loadFile(String path) =>
      _call(() => _hostApi.loadFile(webViewId, path));

  Future<void> reload() => _call(() => _hostApi.reload(webViewId));

  /// Pauses the page's background activity, for example when the app shows
  /// something on top of the WebView or goes to the background. Call
  /// [resume] to undo it.
  ///
  /// Android pauses what `WebView.onPause` pauses: animations, geolocation
  /// and plugins; JavaScript timers keep running unless [pauseTimers] is
  /// called too. iOS suspends the playback of every audio and video element
  /// in the page; WebKit has no other pause. Neither stops a download or
  /// a page load.
  ///
  /// Android: `WebView.onPause()`.
  /// iOS: `WKWebView.setAllMediaPlaybackSuspended(_:)`.
  Future<void> pause() => _call(() => _hostApi.pause(webViewId));

  /// Undoes [pause].
  ///
  /// Android: `WebView.onResume()`.
  /// iOS: `WKWebView.setAllMediaPlaybackSuspended(_:)` with `false`; media
  /// that was playing before [pause] stays paused until the page plays it.
  Future<void> resume() => _call(() => _hostApi.resume(webViewId));

  /// Android only: pauses the layout, parsing and JavaScript timers of
  /// **every** WebView in the app, not just this one. Does nothing on iOS.
  /// Undo with [resumeTimers].
  ///
  /// Android: `WebView.pauseTimers()`.
  Future<void> pauseTimers() => _call(() => _hostApi.pauseTimers(webViewId));

  /// Android only: undoes [pauseTimers] for every WebView in the app. Does
  /// nothing on iOS.
  ///
  /// Android: `WebView.resumeTimers()`.
  Future<void> resumeTimers() => _call(() => _hostApi.resumeTimers(webViewId));

  Future<void> stopLoading() => _call(() => _hostApi.stopLoading(webViewId));

  Future<void> goBack() => _call(() => _hostApi.goBack(webViewId));

  Future<void> goForward() => _call(() => _hostApi.goForward(webViewId));

  Future<bool> canGoBack() => _call(() => _hostApi.canGoBack(webViewId));

  Future<bool> canGoForward() => _call(() => _hostApi.canGoForward(webViewId));

  Future<String?> currentUrl() => _call(() => _hostApi.getUrl(webViewId));

  Future<String?> title() => _call(() => _hostApi.getTitle(webViewId));

  /// Runs [source] and returns its result decoded from JSON
  /// (`null`, `bool`, `num`, `String`, `List` or `Map`).
  Future<Object?> runJavaScriptReturningResult(String source) async {
    final json = await _call(
      () => _hostApi.evaluateJavaScript(webViewId, source),
    );
    return json == null ? null : jsonDecode(json);
  }

  /// Runs [source] and ignores its result.
  Future<void> runJavaScript(String source) =>
      _call(() => _hostApi.evaluateJavaScript(webViewId, source));

  /// Called as a search started by [findText] makes progress, with the
  /// zero-based index of the highlighted match, the number of matches found so
  /// far and whether the count is final. Use it to keep a "3 of 12" label in
  /// sync.
  ///
  /// Android reports every update while WebView counts, so `isDone` is `false`
  /// until the last one. iOS reports one final update per [findText] call
  /// (`isDone` is always `true`); WebKit does not report counts, so the plugin
  /// counts occurrences of the query in the page text and tracks the active
  /// index itself. That count can differ from the highlights for text WebKit
  /// searches differently (for example inside iframes), and the index follows
  /// the search direction only.
  ///
  /// Android: `WebView.setFindListener`.
  /// iOS: `WKWebView.find(_:configuration:)` plus a page-text count.
  final FindResultCallback? onFindResult;

  /// Finds [query] in the page and highlights a match.
  ///
  /// A new [query] starts at the first match; calling again with the same
  /// [query] moves to the next match, or the previous one when [forward] is
  /// `false`, wrapping around at the ends. An empty [query] clears the
  /// highlights. Call [clearMatches] when the user closes the search UI.
  ///
  /// On iOS [FindResult.matchCount] and [FindResult.activeMatchIndex] are
  /// best-effort; see [onFindResult]. Needs iOS 16 or later, which this
  /// package already requires.
  Future<FindResult> findText(String query, {bool forward = true}) async {
    final message = await _call(
      () => _hostApi.findText(webViewId, query, forward),
    );
    return FindResult.fromMessage(message);
  }

  /// Removes the highlights left by [findText].
  Future<void> clearMatches() => _call(() => _hostApi.clearMatches(webViewId));

  /// Scrolls the page to [x], [y] (logical pixels) without animation.
  Future<void> scrollTo(double x, double y) =>
      _call(() => _hostApi.scrollTo(webViewId, x, y));

  /// Scrolls the page by [dx], [dy] (logical pixels) without animation.
  Future<void> scrollBy(double dx, double dy) =>
      _call(() => _hostApi.scrollBy(webViewId, dx, dy));

  /// Multiplies the page's zoom scale by [factor], which must be positive.
  ///
  /// The platform keeps the result within the page's zoom limits, so a page
  /// that forbids zooming (`user-scalable=no`) ignores it. On Android the
  /// WebView must allow zooming ([AndroidWebViewSettings.supportZoom] and
  /// [AndroidWebViewSettings.builtInZoomControls]). This is independent of
  /// [WebViewSettings.textZoom]. Android ignores the call until the page has
  /// been drawn, so a call right after the page finished loading can be lost.
  ///
  /// Android: `WebView.zoomBy(float)`.
  /// iOS: `UIScrollView.setZoomScale(_:animated:)` on `WKWebView.scrollView`.
  Future<void> zoomBy(double factor) {
    assert(factor > 0, 'factor must be positive');
    return _call(() => _hostApi.zoomBy(webViewId, factor));
  }

  /// Sets the page's zoom scale to [scale], which must be positive.
  ///
  /// See [zoomBy] for the limits that apply, and [getZoomScale] for what the
  /// number means. Android has no absolute setter, so the plugin calls
  /// `zoomBy` with the ratio to the current scale; the result can be slightly
  /// off for that reason.
  ///
  /// Android: `WebView.zoomBy(float)`.
  /// iOS: `UIScrollView.setZoomScale(_:animated:)` on `WKWebView.scrollView`.
  Future<void> setZoomScale(double scale) {
    assert(scale > 0, 'scale must be positive');
    return _call(() => _hostApi.setZoomScale(webViewId, scale));
  }

  /// The current zoom scale of the page, in logical pixels per CSS pixel.
  ///
  /// `1.0` shows one CSS pixel as one logical pixel. A page without a
  /// viewport `<meta>` tag is usually laid out wider than the screen and
  /// starts below `1.0`.
  ///
  /// Android: `WebView.getScale()` divided by the display density.
  /// iOS: `UIScrollView.zoomScale` of `WKWebView.scrollView`.
  Future<double> getZoomScale() =>
      _call(() => _hostApi.getZoomScale(webViewId));

  /// The current scroll offset of the page in logical pixels.
  Future<Offset> scrollPosition() async {
    final position = await _call(() => _hostApi.getScrollPosition(webViewId));
    return Offset(position.x, position.y);
  }

  /// Saves the back/forward history and scroll position as opaque bytes, or
  /// `null` when there is nothing to save (for example before the first load).
  ///
  /// The format is platform specific and not stable across OS or app versions:
  /// only pass it to [restoreState] on the same platform, and discard it when
  /// that returns `false`.
  Future<Uint8List?> saveState() => _call(() => _hostApi.saveState(webViewId));

  /// Restores bytes returned by [saveState]. Returns `false` when the
  /// platform cannot read them; the WebView is then left unchanged.
  Future<bool> restoreState(Uint8List state) =>
      _call(() => _hostApi.restoreState(webViewId, state));

  /// Opens the system print dialog for the current page.
  ///
  /// Returns once the dialog is presented, not when printing finishes. The
  /// WebView must be shown (attached to an [AdvancedWebView]); otherwise this
  /// throws a `PlatformException` with code `not-attached`. [jobName] titles
  /// the print job (the page title by default on Android, the document name
  /// on iOS).
  Future<void> printPage({String? jobName}) =>
      _call(() => _hostApi.printPage(webViewId, jobName));

  /// Reports what is at [position] (logical pixels, relative to the WebView,
  /// as given to [onLongPress]): a link, an image, both, or neither.
  ///
  /// Implemented with `document.elementFromPoint`, so it only sees the main
  /// frame and behaves the same on Android and iOS.
  Future<WebViewHitTestResult> hitTest(Offset position) async {
    final result = await runJavaScriptReturningResult(
      hitTestScript(position.dx, position.dy),
    );
    return WebViewHitTestResult.fromJson(result);
  }

  /// Captures the visible area of the WebView as a PNG image.
  ///
  /// Returns `null` when nothing can be captured, for example while the view
  /// has no size. Only what is currently on screen is captured, not the whole
  /// page.
  Future<Uint8List?> takeScreenshot() =>
      _call(() => _hostApi.takeScreenshot(webViewId));

  /// Renders the current page to a PDF and returns its bytes.
  ///
  /// The page should have finished loading. Android lays the content out on
  /// A4 pages the way printing does (the page's print styles apply). iOS
  /// returns a single page as tall as the whole content, with the screen
  /// styles. Throws a `PlatformException` with code `pdf-failed` when the
  /// platform cannot render the page.
  ///
  /// Android: `WebView.createPrintDocumentAdapter` written to a temporary
  /// file. iOS: `WKWebView.pdf(configuration:)`.
  Future<Uint8List> createPdf() => _call(() => _hostApi.createPdf(webViewId));

  Future<void> updateSettings(WebViewSettings settings) async {
    await _call(() => _hostApi.updateSettings(webViewId, settings.toMessage()));
    _settings = settings;
  }

  /// Registers [script] to run in pages loaded from now on.
  ///
  /// It does not run in the page that is currently shown; load or reload a
  /// page afterwards. Scripts passed to the constructor are registered before
  /// the first load.
  ///
  /// Android: `WebViewCompat.addDocumentStartJavaScript(WebView, String, Set)`;
  /// requires `WebViewFeature.DOCUMENT_START_SCRIPT`. `atDocumentEnd` scripts
  /// are wrapped to wait for `DOMContentLoaded`.
  /// iOS: `WKUserContentController.addUserScript(_:)` with a `WKUserScript`.
  Future<void> addUserScript(UserScript script) =>
      _call(() => _hostApi.addUserScript(webViewId, script.toMessage()));

  /// Removes every script added with [addUserScript] or the constructor.
  ///
  /// Android: `ScriptHandler.remove()` for each registered script.
  /// iOS: `WKUserContentController.removeAllUserScripts()`; the JavaScript
  /// channel shims are registered again afterwards.
  Future<void> removeAllUserScripts() =>
      _call(() => _hostApi.removeAllUserScripts(webViewId));

  /// Stores [cookie] in the WebView's cookie store.
  ///
  /// Completes when the cookie has been stored; load or reload a page
  /// afterwards for it to be sent.
  ///
  /// Android and iOS differ: Android's cookie store is shared by all WebViews
  /// of the app, iOS's by all WebViews that use the default data store.
  ///
  /// Android: `CookieManager.setCookie(String, String, ValueCallback)`.
  /// iOS: `WKHTTPCookieStore.setCookie(_:)`.
  Future<void> setCookie(WebViewCookie cookie) =>
      _call(() => _hostApi.setCookie(webViewId, cookie.toMessage()));

  /// Returns the cookies the WebView would send to [url].
  ///
  /// Android and iOS differ: Android only reports [WebViewCookie.name] and
  /// [WebViewCookie.value]; the other fields are filled with the host of [url],
  /// `/` and `false`. iOS reports every attribute.
  ///
  /// Android: `CookieManager.getCookie(String)`.
  /// iOS: `WKHTTPCookieStore.allCookies()`, filtered by [url].
  Future<List<WebViewCookie>> getCookies(String url) async {
    final cookies = await _call(() => _hostApi.getCookies(webViewId, url));
    return cookies.map(WebViewCookie.fromMessage).toList();
  }

  /// Removes every cookie from the WebView's cookie store.
  ///
  /// Android: `CookieManager.removeAllCookies(ValueCallback)`.
  /// iOS: `WKHTTPCookieStore.allCookies()` and `deleteCookie(_:)` for each cookie.
  Future<void> clearCookies() => _call(() => _hostApi.clearCookies(webViewId));

  /// Removes website data of the given [types] (all of them by default).
  /// Cookies are not included; use [clearCookies].
  ///
  /// The data is shared, not per controller: it is cleared for every WebView
  /// of the app on Android, and for every WebView that uses the same data store
  /// on iOS (the default one, unless [IOSWebViewSettings.incognito] is set).
  ///
  /// Android has no way to clear `localStorage` and IndexedDB separately, so
  /// selecting [WebsiteDataType.localStorage] or [WebsiteDataType.indexedDb]
  /// clears all DOM storage of the app (including WebSQL and the Cache API).
  /// iOS clears exactly the selected types.
  ///
  /// Android: `WebView.clearCache(true)` and `WebStorage.deleteAllData()`.
  /// iOS: `WKWebsiteDataStore.removeData(ofTypes:modifiedSince:)`.
  Future<void> clearWebsiteData({
    Set<WebsiteDataType> types = const {
      WebsiteDataType.cache,
      WebsiteDataType.localStorage,
      WebsiteDataType.indexedDb,
    },
  }) => _call(
    () => _hostApi.clearWebsiteData(webViewId, [
      for (final type in WebsiteDataType.values)
        if (types.contains(type))
          switch (type) {
            WebsiteDataType.cache => WebsiteDataTypeMessage.cache,
            WebsiteDataType.localStorage => WebsiteDataTypeMessage.localStorage,
            WebsiteDataType.indexedDb => WebsiteDataTypeMessage.indexedDb,
          },
    ]),
  );

  /// Destroys the native WebView. The controller cannot be used afterwards.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _dispatcher.unregister(webViewId);
    await _created;
    await _hostApi.dispose(webViewId);
  }

  Future<T> _call<T>(Future<T> Function() body) async {
    if (_isDisposed) {
      throw StateError('AdvancedWebViewController($webViewId) was disposed');
    }
    await _created;
    return body();
  }
}

/// Adapts platform messages to the public callbacks, keeping the
/// [WebViewEventListener] methods off the controller's public API.
class _EventListener implements WebViewEventListener {
  _EventListener(this._controller);

  final AdvancedWebViewController _controller;

  @override
  void onPageStarted(String url) => _controller.onPageStarted?.call(url);

  @override
  void onPageFinished(String url) => _controller.onPageFinished?.call(url);

  @override
  void onProgressChanged(int progress) =>
      _controller.onProgress?.call(progress);

  @override
  void onTitleChanged(String? title) => _controller.onTitleChanged?.call(title);

  @override
  void onScrollChanged(double x, double y) =>
      _controller.onScrollChanged?.call(Offset(x, y));

  @override
  void onLongPress(double x, double y) =>
      _controller.onLongPress?.call(Offset(x, y));

  @override
  void onConsoleMessage(ConsoleMessageMessage message) =>
      _controller.onConsoleMessage?.call(
        WebViewConsoleMessage(
          level: WebViewConsoleMessageLevel.values[message.level.index],
          message: message.message,
          sourceUrl: message.sourceUrl,
          lineNumber: message.lineNumber,
        ),
      );

  @override
  void onRenderProcessGone(RenderProcessGoneMessage details) => _controller
      .onRenderProcessGone
      ?.call(RenderProcessGone(didCrash: details.didCrash));

  @override
  void onReceivedHttpError(HttpErrorMessage error) =>
      _controller.onHttpError?.call(
        HttpError(
          url: error.url,
          statusCode: error.statusCode,
          isMainFrame: error.isMainFrame,
        ),
      );

  @override
  void onReceivedError(WebResourceErrorMessage error) =>
      _controller.onWebResourceError?.call(
        WebResourceError(
          errorCode: error.errorCode,
          message: error.message,
          isMainFrame: error.isMainFrame,
          url: error.url,
        ),
      );

  @override
  Future<NavigationDecisionMessage> shouldOverrideUrlLoading(
    NavigationRequestMessage request,
  ) async {
    final callback = _controller.onNavigationRequest;
    if (callback == null) return NavigationDecisionMessage.navigate;
    final decision = await callback(
      NavigationRequest(url: request.url, isMainFrame: request.isMainFrame),
    );
    return switch (decision) {
      NavigationDecision.navigate => NavigationDecisionMessage.navigate,
      NavigationDecision.prevent => NavigationDecisionMessage.prevent,
    };
  }

  @override
  void onJavaScriptMessage(String channelName, String message) =>
      _controller._javaScriptChannels[channelName]?.call(message);

  @override
  void onNewWindowRequest(String url) => _controller.onNewWindow?.call(url);

  @override
  void onInAppBrowserClosed() => _controller.onInAppBrowserClosed?.call();

  @override
  void onDownloadStart(DownloadRequestMessage request) =>
      _controller.onDownloadStart?.call(
        DownloadRequest(
          url: request.url,
          suggestedFilename: request.suggestedFilename,
          mimeType: request.mimeType,
          contentLength: request.contentLength,
        ),
      );

  @override
  Future<SslErrorDecisionMessage> onSslError(SslErrorMessage error) async {
    final callback = _controller.onSslError;
    if (callback == null) return SslErrorDecisionMessage.cancel;
    final decision = await callback(
      SslError(url: error.url, host: error.host, message: error.message),
    );
    return switch (decision) {
      SslErrorDecision.proceed => SslErrorDecisionMessage.proceed,
      SslErrorDecision.cancel => SslErrorDecisionMessage.cancel,
    };
  }

  @override
  Future<ClientCertResponseMessage> onClientCertRequest(
    ClientCertRequestMessage request,
  ) async {
    final callback = _controller.onClientCertRequest;
    if (callback == null) {
      return ClientCertResponseMessage(action: ClientCertActionMessage.cancel);
    }
    final response = await callback(
      ClientCertRequest(
        host: request.host,
        port: request.port,
        realm: request.realm,
      ),
    );
    return ClientCertResponseMessage(
      action: switch (response.action) {
        ClientCertAction.proceed => ClientCertActionMessage.proceed,
        ClientCertAction.cancel => ClientCertActionMessage.cancel,
        ClientCertAction.ignore => ClientCertActionMessage.ignore,
      },
      pkcs12: response.pkcs12,
      password: response.password,
    );
  }

  @override
  Future<HttpAuthCredentialsMessage?> onHttpAuthRequest(
    HttpAuthRequestMessage request,
  ) async {
    final callback = _controller.onHttpAuthRequest;
    if (callback == null) return null;
    final credentials = await callback(
      HttpAuthRequest(host: request.host, realm: request.realm),
    );
    return credentials == null
        ? null
        : HttpAuthCredentialsMessage(
            username: credentials.username,
            password: credentials.password,
          );
  }

  @override
  Future<PermissionDecisionMessage> onPermissionRequest(
    PermissionRequestMessage request,
  ) async {
    final callback = _controller.onPermissionRequest;
    if (callback == null) return PermissionDecisionMessage.deny;
    final decision = await callback(
      PermissionRequest(
        origin: request.origin,
        resources: [
          for (final resource in request.resources)
            switch (resource) {
              PermissionResourceMessage.camera => PermissionResource.camera,
              PermissionResourceMessage.microphone =>
                PermissionResource.microphone,
              PermissionResourceMessage.geolocation =>
                PermissionResource.geolocation,
            },
        ],
      ),
    );
    return switch (decision) {
      PermissionDecision.grant => PermissionDecisionMessage.grant,
      PermissionDecision.deny => PermissionDecisionMessage.deny,
    };
  }

  @override
  void onFaviconChanged(String? url) => _controller.onFaviconChanged?.call(url);

  @override
  void onEnterFullscreen() => _controller.onEnterFullscreen?.call();

  @override
  void onExitFullscreen() => _controller.onExitFullscreen?.call();

  @override
  void onFindResult(int activeMatchIndex, int numberOfMatches, bool isDone) =>
      _controller.onFindResult?.call(activeMatchIndex, numberOfMatches, isDone);

  @override
  Future<InterceptResponseMessage?> onInterceptRequest(
    InterceptRequestMessage request,
  ) async {
    final callback = _controller.onInterceptRequest;
    if (callback == null) return null;
    final response = await callback(
      InterceptedRequest(
        url: request.url,
        method: request.method,
        headers: request.headers,
        isMainFrame: request.isMainFrame,
      ),
    );
    if (response == null) return null;
    return InterceptResponseMessage(
      statusCode: response.statusCode,
      mimeType: response.mimeType,
      headers: response.headers,
      body: response.body,
    );
  }

  @override
  Future<JsDialogResultMessage> onJsDialog(
    JsDialogRequestMessage request,
  ) async {
    final callback = _controller.onJsDialog;
    if (callback == null) return JsDialogResultMessage(accepted: false);
    final response = await callback(
      JsDialogRequest(
        type: switch (request.type) {
          JsDialogTypeMessage.alert => JsDialogType.alert,
          JsDialogTypeMessage.confirm => JsDialogType.confirm,
          JsDialogTypeMessage.prompt => JsDialogType.prompt,
        },
        message: request.message,
        url: request.url,
        defaultText: request.defaultText,
      ),
    );
    return JsDialogResultMessage(
      accepted: response.accepted,
      text: response.accepted ? response.text : null,
    );
  }

  @override
  Future<String> onJavaScriptHandlerCall(
    String handlerName,
    String argsJson,
  ) async {
    final handler = _controller._javaScriptHandlers[handlerName];
    if (handler == null) {
      throw ArgumentError('No JavaScript handler named "$handlerName"');
    }
    final arguments = (jsonDecode(argsJson) as List).cast<Object?>();
    return jsonEncode(await handler(arguments));
  }
}
