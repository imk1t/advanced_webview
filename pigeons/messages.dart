// Pigeon definition for the Dart <-> native (Android/iOS) contract.
//
// This file is the single source of truth for every message that crosses the
// platform channel. After editing it, regenerate the bindings:
//
//   dart run pigeon --input pigeons/messages.dart
//
// Every WebView instance is addressed by a Dart-allocated `webViewId`, so one
// HostApi / FlutterApi pair serves all instances.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/platform/messages.g.dart',
    dartPackageName: 'advanced_webview',
    kotlinOut: 'android/src/main/kotlin/dev/k1t/advanced_webview/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.k1t.advanced_webview'),
    swiftOut: 'ios/advanced_webview/Sources/advanced_webview/Messages.g.swift',
  ),
)
// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------
enum CacheModeMessage { normal, preferCache, cacheOnly, noCache }

enum ContentModeMessage { recommended, mobile, desktop }

enum UserInterfaceStyleMessage { unspecified, light, dark }

enum MixedContentModeMessage { neverAllow, compatibility, alwaysAllow }

class WebViewSettingsMessage {
  WebViewSettingsMessage({
    required this.javaScriptEnabled,
    required this.mediaPlaybackRequiresUserGesture,
    required this.allowsInlineMediaPlayback,
    required this.supportZoom,
    required this.builtInZoomControls,
    required this.displayZoomControls,
    required this.transparentBackground,
    required this.passkeysEnabled,
    required this.allowsBackForwardNavigationGestures,
    required this.inspectable,
    required this.textZoom,
    required this.cacheMode,
    required this.incognito,
    required this.javaScriptCanOpenWindowsAutomatically,
    required this.scrollbarsVisible,
    required this.overScrollEnabled,
    required this.pullToRefreshEnabled,
    required this.domStorageEnabled,
    required this.allowFileAccess,
    required this.allowContentAccess,
    required this.mixedContentMode,
    required this.contentMode,
    required this.allowsLinkPreview,
    required this.geolocationEnabled,
    required this.algorithmicDarkeningAllowed,
    required this.userInterfaceStyle,
    this.minimumFontSize,
    this.userAgent,
    this.applicationNameForUserAgent,
  });

  bool javaScriptEnabled;
  bool mediaPlaybackRequiresUserGesture;

  /// iOS only. Ignored on Android.
  bool allowsInlineMediaPlayback;

  /// Android only. Ignored on iOS.
  bool supportZoom;

  /// Android only. Ignored on iOS.
  bool builtInZoomControls;

  /// Android only. Ignored on iOS.
  bool displayZoomControls;
  bool transparentBackground;

  /// Android only. Ignored on iOS, where WebAuthn is governed by entitlements.
  bool passkeysEnabled;

  /// iOS only. Ignored on Android.
  bool allowsBackForwardNavigationGestures;

  /// Android: process-wide `WebView.setWebContentsDebuggingEnabled`.
  /// iOS: `WKWebView.isInspectable`.
  bool inspectable;

  /// Percent, 100 is normal. Android: `WebSettings.setTextZoom`. iOS: scales
  /// the whole page with `WKWebView.pageZoom`.
  int textZoom;

  /// Android: `WebSettings.setCacheMode`. iOS: `URLRequest.cachePolicy` of
  /// requests started with `loadUrl`.
  CacheModeMessage cacheMode;

  /// iOS only, creation only: `WKWebsiteDataStore.nonPersistent()`. Ignored on
  /// Android, whose WebView shares its data across the app.
  bool incognito;

  /// Android: `WebSettings.setJavaScriptCanOpenWindowsAutomatically`. iOS:
  /// `WKPreferences.javaScriptCanOpenWindowsAutomatically`.
  bool javaScriptCanOpenWindowsAutomatically;

  /// Android: vertical and horizontal scroll bars. iOS: scroll indicators.
  bool scrollbarsVisible;

  /// Android: `View.setOverScrollMode`. iOS: `UIScrollView.bounces`.
  bool overScrollEnabled;

  /// Android: `SwipeRefreshLayout`. iOS: `UIRefreshControl`. A pull reloads the
  /// page.
  bool pullToRefreshEnabled;

  /// Android: `WebSettings.setDomStorageEnabled`. iOS has no switch.
  bool domStorageEnabled;

  /// Android: `WebSettings.setAllowFileAccess`. iOS has no equivalent.
  bool allowFileAccess;

  /// Android: `WebSettings.setAllowContentAccess`. iOS has no equivalent.
  bool allowContentAccess;

  /// Android: `WebSettings.setMixedContentMode`. iOS has no equivalent.
  MixedContentModeMessage mixedContentMode;

  /// iOS only: `WKWebpagePreferences.preferredContentMode`. Ignored on
  /// Android.
  ContentModeMessage contentMode;

  /// iOS only: `WKWebView.allowsLinkPreview`. Ignored on Android.
  bool allowsLinkPreview;

  /// Android: `WebSettings.setGeolocationEnabled`. iOS has no switch.
  bool geolocationEnabled;

  /// Android: `WebSettingsCompat.setAlgorithmicDarkeningAllowed`, when the
  /// installed WebView supports it. iOS has no equivalent.
  bool algorithmicDarkeningAllowed;

  /// iOS: `UIView.overrideUserInterfaceStyle`. Ignored on Android.
  UserInterfaceStyleMessage userInterfaceStyle;

  /// Android: `WebSettings.setMinimumFontSize` (sp). iOS:
  /// `WKPreferences.minimumFontSize` (pt). `null` uses the platform default.
  int? minimumFontSize;
  String? userAgent;

  /// iOS only, creation only: `WKWebViewConfiguration.applicationNameForUserAgent`.
  /// Ignored on Android. `null` uses the platform default.
  String? applicationNameForUserAgent;
}

enum ConsoleMessageLevelMessage { debug, log, info, warning, error }

class ConsoleMessageMessage {
  ConsoleMessageMessage({
    required this.level,
    required this.message,
    this.sourceUrl,
    this.lineNumber,
  });

  ConsoleMessageLevelMessage level;
  String message;

  /// Script that logged the message. `null` on iOS, which does not report it.
  String? sourceUrl;

  /// Line in [sourceUrl]. `null` on iOS, which does not report it.
  int? lineNumber;
}

enum UserScriptInjectionTimeMessage { atDocumentStart, atDocumentEnd }

class UserScriptMessage {
  UserScriptMessage({
    required this.source,
    required this.injectionTime,
    required this.mainFrameOnly,
  });

  String source;
  UserScriptInjectionTimeMessage injectionTime;
  bool mainFrameOnly;
}

class CreationParamsMessage {
  CreationParamsMessage({
    required this.webViewId,
    required this.settings,
    required this.javaScriptChannelNames,
    required this.javaScriptHandlerNames,
    required this.javaScriptHandlerObjectName,
    required this.hasNavigationDelegate,
    required this.hasNewWindowDelegate,
    required this.hasPermissionDelegate,
    required this.hasDownloadDelegate,
    required this.hasSslErrorDelegate,
    required this.hasHttpAuthDelegate,
    required this.hasClientCertDelegate,
    required this.hasScrollDelegate,
    required this.hasLongPressDelegate,
    required this.hasConsoleMessageDelegate,
    required this.hasJsDialogDelegate,
    required this.hasHttpErrorDelegate,
    required this.hasFindDelegate,
    required this.hasFaviconDelegate,
    required this.hasFullscreenDelegate,
    required this.interceptSchemes,
    required this.userScripts,
  });

  int webViewId;
  WebViewSettingsMessage settings;

  /// Names exposed to JS as `window.<name>.postMessage(String)`.
  List<String> javaScriptChannelNames;

  /// Handlers the page can call with `window.advanced_webview.callHandler`.
  /// The bridge is only installed when this is not empty.
  List<String> javaScriptHandlerNames;

  /// Name of the global object (`window.<name>`) that exposes `callHandler`.
  /// Always a valid JavaScript identifier.
  String javaScriptHandlerObjectName;

  /// When false, native code never round-trips navigation decisions to Dart.
  bool hasNavigationDelegate;

  /// When false, `window.open` and `target="_blank"` load in the same WebView
  /// and never round-trip to Dart.
  bool hasNewWindowDelegate;

  /// When false, permission requests (camera, microphone, geolocation) are
  /// denied natively without a round trip to Dart.
  bool hasPermissionDelegate;

  /// When false, downloads are left to the platform default and never
  /// round-trip to Dart.
  bool hasDownloadDelegate;

  /// When false, certificate errors are refused natively without a round trip
  /// to Dart.
  bool hasSslErrorDelegate;

  /// When false, HTTP authentication challenges get the platform default
  /// handling without a round trip to Dart.
  bool hasHttpAuthDelegate;

  /// When false, client certificate requests get the platform default
  /// handling (Android cancels them) without a round trip to Dart.
  bool hasClientCertDelegate;

  /// When false, scroll changes are never reported to Dart.
  bool hasScrollDelegate;

  /// When false, long presses are never reported to Dart.
  bool hasLongPressDelegate;

  /// When false, console output is never reported to Dart (and, on iOS, the
  /// `console` wrapper script is not injected).
  bool hasConsoleMessageDelegate;

  /// When false, `alert`, `confirm` and `prompt` use the platform's default
  /// dialog and never round-trip to Dart.
  bool hasJsDialogDelegate;

  /// When false, HTTP error statuses are never reported to Dart.
  bool hasHttpErrorDelegate;

  /// When false, find progress is never reported to Dart.
  bool hasFindDelegate;

  /// When false, the favicon is never looked up or reported.
  bool hasFaviconDelegate;

  /// When false, fullscreen changes are still shown natively but never
  /// reported to Dart.
  bool hasFullscreenDelegate;

  /// Lower-case URL schemes whose requests are answered by Dart through
  /// `onInterceptRequest`. Empty when the app has no intercept callback.
  List<String> interceptSchemes;

  /// Scripts injected into every page loaded after creation.
  List<UserScriptMessage> userScripts;
}

class NavigationRequestMessage {
  NavigationRequestMessage({required this.url, required this.isMainFrame});

  String url;
  bool isMainFrame;
}

enum NavigationDecisionMessage { navigate, prevent }

class HttpErrorMessage {
  HttpErrorMessage({
    required this.url,
    required this.statusCode,
    required this.isMainFrame,
  });

  String url;
  int statusCode;
  bool isMainFrame;
}

class RenderProcessGoneMessage {
  RenderProcessGoneMessage({this.didCrash});

  /// True when the renderer crashed, false when the system killed it (for
  /// example to free memory), null when the platform does not say.
  bool? didCrash;
}

class WebResourceErrorMessage {
  WebResourceErrorMessage({
    required this.errorCode,
    required this.message,
    required this.isMainFrame,
    this.url,
  });

  int errorCode;
  String message;
  bool isMainFrame;
  String? url;
}

class SslErrorMessage {
  SslErrorMessage({
    required this.url,
    required this.host,
    required this.message,
  });

  String url;
  String host;
  String message;
}

enum SslErrorDecisionMessage { proceed, cancel }

class HttpAuthRequestMessage {
  HttpAuthRequestMessage({required this.host, this.realm});

  String host;
  String? realm;
}

class ClientCertRequestMessage {
  ClientCertRequestMessage({
    required this.host,
    required this.port,
    this.realm,
  });

  String host;
  int port;

  /// iOS only: `URLProtectionSpace.realm`. Always null on Android.
  String? realm;
}

enum ClientCertActionMessage { proceed, cancel, ignore }

class ClientCertResponseMessage {
  ClientCertResponseMessage({required this.action, this.pkcs12, this.password});

  ClientCertActionMessage action;

  /// A PKCS#12 (`.p12`) file. Only used with `proceed`.
  Uint8List? pkcs12;
  String? password;
}

class HttpAuthCredentialsMessage {
  HttpAuthCredentialsMessage({required this.username, required this.password});

  String username;
  String password;
}

class DownloadRequestMessage {
  DownloadRequestMessage({
    required this.url,
    this.suggestedFilename,
    this.mimeType,
    this.contentLength,
  });

  String url;
  String? suggestedFilename;
  String? mimeType;

  /// Size in bytes; null when the server did not say.
  int? contentLength;
}

enum PermissionResourceMessage { camera, microphone, geolocation }

class PermissionRequestMessage {
  PermissionRequestMessage({required this.origin, required this.resources});

  /// Origin of the requesting page, e.g. `https://example.com`.
  String origin;
  List<PermissionResourceMessage> resources;
}

enum PermissionDecisionMessage { grant, deny }

enum JsDialogTypeMessage { alert, confirm, prompt }

class JsDialogRequestMessage {
  JsDialogRequestMessage({
    required this.type,
    required this.message,
    required this.url,
    this.defaultText,
  });

  JsDialogTypeMessage type;
  String message;

  /// URL of the page that opened the dialog.
  String url;

  /// Initial text of a `prompt`; null for the other types.
  String? defaultText;
}

class JsDialogResultMessage {
  JsDialogResultMessage({required this.accepted, this.text});

  /// OK was pressed. Always true for an `alert`.
  bool accepted;

  /// Text entered in a `prompt`; null when not accepted or for other types.
  String? text;
}

class InterceptRequestMessage {
  InterceptRequestMessage({
    required this.url,
    required this.method,
    required this.headers,
    required this.isMainFrame,
  });

  String url;
  String method;
  Map<String, String> headers;
  bool isMainFrame;
}

class InterceptResponseMessage {
  InterceptResponseMessage({
    required this.statusCode,
    required this.mimeType,
    required this.headers,
    required this.body,
  });

  int statusCode;

  /// May carry a charset parameter, e.g. `text/html; charset=utf-8`.
  String mimeType;
  Map<String, String> headers;
  Uint8List body;
}

class FindResultMessage {
  FindResultMessage({
    required this.found,
    this.matchCount,
    this.activeMatchIndex,
  });

  bool found;

  /// Total matches on the page. A best-effort count on iOS.
  int? matchCount;

  /// Zero-based index of the highlighted match. Tracked best-effort on iOS.
  int? activeMatchIndex;
}

class ScrollPositionMessage {
  ScrollPositionMessage({required this.x, required this.y});

  /// Horizontal offset in logical pixels.
  double x;

  /// Vertical offset in logical pixels.
  double y;
}

enum WebsiteDataTypeMessage { cache, localStorage, indexedDb }

enum HttpMethodMessage { get, post }

class CookieMessage {
  CookieMessage({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    required this.isSecure,
    required this.isHttpOnly,
    this.expiresMillis,
  });

  String name;
  String value;
  String domain;
  String path;
  bool isSecure;
  bool isHttpOnly;

  /// Expiry as milliseconds since the Unix epoch; null for a session cookie.
  int? expiresMillis;
}

/// Chrome of the full-screen in-app browser that hosts an existing WebView.
class InAppBrowserParamsMessage {
  InAppBrowserParamsMessage({
    required this.webViewId,
    required this.showUrl,
    required this.showNavigationButtons,
    this.toolbarColor,
    this.toolbarTitle,
    this.closeButtonLabel,
  });

  /// The WebView created with `create`; the browser shows it and does not own
  /// its lifetime.
  int webViewId;
  bool showUrl;
  bool showNavigationButtons;

  /// Toolbar background as ARGB (`Color.toARGB32`); `null` uses the platform
  /// default.
  int? toolbarColor;

  /// Fixed toolbar title; `null` shows the page title.
  String? toolbarTitle;

  /// Label of the button that closes the browser; `null` uses a localized
  /// platform default.
  String? closeButtonLabel;
}

// ---------------------------------------------------------------------------
// Dart -> native
// ---------------------------------------------------------------------------

@HostApi()
abstract class AdvancedWebViewHostApi {
  /// Creates the native WebView. Must be called before the platform view with
  /// the same `webViewId` is attached.
  void create(CreationParamsMessage params);

  void dispose(int webViewId);

  void loadUrl(int webViewId, String url, Map<String, String> headers);

  void loadHtmlString(int webViewId, String html, String? baseUrl);

  /// Loads `url` with an explicit method. A `body` is only sent with POST.
  void loadRequest(
    int webViewId,
    String url,
    HttpMethodMessage method,
    Map<String, String> headers,
    Uint8List? body,
  );

  /// Loads a Flutter asset declared in the app's `pubspec.yaml`.
  void loadFlutterAsset(int webViewId, String key);

  /// Loads a file from the device's file system by absolute path.
  void loadFile(int webViewId, String path);

  void reload(int webViewId);

  /// Pauses what the page does in the background. Android: `WebView.onPause`.
  /// iOS: suspends media playback of all media in the page.
  @async
  void pause(int webViewId);

  /// Undoes `pause`.
  @async
  void resume(int webViewId);

  /// Android only: `WebView.pauseTimers`, which is process-wide. No-op on iOS.
  void pauseTimers(int webViewId);

  /// Android only: `WebView.resumeTimers`, which is process-wide. No-op on iOS.
  void resumeTimers(int webViewId);

  void stopLoading(int webViewId);

  void goBack(int webViewId);

  void goForward(int webViewId);

  bool canGoBack(int webViewId);

  bool canGoForward(int webViewId);

  String? getUrl(int webViewId);

  String? getTitle(int webViewId);

  /// Returns the evaluation result encoded as JSON (or null).
  @async
  String? evaluateJavaScript(int webViewId, String source);

  /// Returns a PNG of the visible area, or null when it cannot be captured
  /// (for example when the view has no size yet).
  @async
  Uint8List? takeScreenshot(int webViewId);

  /// Renders the current page to a PDF. Android lays it out on A4 pages; iOS
  /// produces one page as tall as the content. Fails with `pdf-failed` when
  /// WebKit or the print framework cannot render it.
  @async
  Uint8List createPdf(int webViewId);

  /// Finds `query` in the page and highlights a match. A new query starts at
  /// the first match; repeating the same query moves to the next or previous.
  @async
  FindResultMessage findText(int webViewId, String query, bool forward);

  /// Removes the highlights left by `findText`.
  void clearMatches(int webViewId);

  /// Scrolls the page to `x`, `y` (logical pixels) without animation.
  void scrollTo(int webViewId, double x, double y);

  /// Scrolls the page by `dx`, `dy` (logical pixels) without animation.
  void scrollBy(int webViewId, double dx, double dy);

  /// Multiplies the current zoom scale by `factor` (greater than 0). Android
  /// calls `WebView.zoomBy`; iOS sets `UIScrollView.zoomScale`.
  void zoomBy(int webViewId, double factor);

  /// Sets the zoom scale. The platform clamps it to the page's limits.
  void setZoomScale(int webViewId, double scale);

  /// The current zoom scale, in device-independent pixels per CSS pixel.
  double getZoomScale(int webViewId);

  ScrollPositionMessage getScrollPosition(int webViewId);

  /// Opaque snapshot of the back/forward list and scroll position, or null
  /// when there is nothing to save. Only valid on the same platform.
  Uint8List? saveState(int webViewId);

  /// Restores a snapshot from `saveState`. Returns false when it cannot be read.
  bool restoreState(int webViewId, Uint8List state);

  /// Opens the system print dialog for the current page. Fails with
  /// `not-attached` when the WebView is not shown in a window.
  void printPage(int webViewId, String? jobName);

  void updateSettings(int webViewId, WebViewSettingsMessage settings);

  @async
  void setCookie(int webViewId, CookieMessage cookie);

  /// Returns the cookies the WebView would send to `url`.
  @async
  List<CookieMessage> getCookies(int webViewId, String url);

  @async
  void clearCookies(int webViewId);

  /// Removes the given kinds of website data. Cookies are not included; see
  /// `clearCookies`.
  @async
  void clearWebsiteData(int webViewId, List<WebsiteDataTypeMessage> types);

  /// Registers a script for pages loaded from now on.
  void addUserScript(int webViewId, UserScriptMessage script);

  void removeAllUserScripts(int webViewId);

  /// Presents the WebView `params.webViewId` full screen with a toolbar. Fails
  /// with `not-attached` when there is no screen to present from and with
  /// `already-open` when it is already presented.
  void openInAppBrowser(InAppBrowserParamsMessage params);

  /// Dismisses the in-app browser; a no-op when it is not open. The WebView
  /// itself stays alive.
  void closeInAppBrowser(int webViewId);
}

// ---------------------------------------------------------------------------
// native -> Dart
// ---------------------------------------------------------------------------

@FlutterApi()
abstract class AdvancedWebViewFlutterApi {
  void onPageStarted(int webViewId, String url);

  void onPageFinished(int webViewId, String url);

  void onProgressChanged(int webViewId, int progress);

  void onTitleChanged(int webViewId, String? title);

  /// Only sent when the controller was created with `hasScrollDelegate`.
  void onScrollChanged(int webViewId, double x, double y);

  /// A long press at `x`, `y` (logical pixels, relative to the WebView).
  /// Only sent when the controller was created with `hasLongPressDelegate`.
  void onLongPress(int webViewId, double x, double y);

  /// A `console.*` call made by the page. Only sent when the controller was
  /// created with `hasConsoleMessageDelegate`.
  void onConsoleMessage(int webViewId, ConsoleMessageMessage message);

  /// Find progress. Only sent when the controller was created with
  /// `hasFindDelegate`. Android sends it as WebView counts (`isDone` false
  /// until it has finished); iOS sends one final update per `findText`.
  void onFindResult(
    int webViewId,
    int activeMatchIndex,
    int numberOfMatches,
    bool isDone,
  );

  /// The favicon URL of the page that just finished loading, or null when it
  /// has none. Only sent when the controller was created with
  /// `hasFaviconDelegate`.
  void onFaviconChanged(int webViewId, String? url);

  /// The page (a video or any element) entered fullscreen. Only sent when the
  /// controller was created with `hasFullscreenDelegate`.
  void onEnterFullscreen(int webViewId);

  /// The page left fullscreen. Only sent when the controller was created with
  /// `hasFullscreenDelegate`.
  void onExitFullscreen(int webViewId);

  /// The process that renders web content crashed or was killed, so the
  /// WebView shows nothing (iOS) or cannot be used any more (Android).
  void onRenderProcessGone(int webViewId, RenderProcessGoneMessage details);

  void onReceivedError(int webViewId, WebResourceErrorMessage error);

  /// A server answered with a status of 400 or more.
  void onReceivedHttpError(int webViewId, HttpErrorMessage error);

  @async
  NavigationDecisionMessage shouldOverrideUrlLoading(
    int webViewId,
    NavigationRequestMessage request,
  );

  void onJavaScriptMessage(int webViewId, String channelName, String message);

  /// The WebView found a certificate problem. Cancelling refuses the load.
  @async
  SslErrorDecisionMessage onSslError(int webViewId, SslErrorMessage error);

  /// A server asked for credentials. Null cancels the request.
  @async
  HttpAuthCredentialsMessage? onHttpAuthRequest(
    int webViewId,
    HttpAuthRequestMessage request,
  );

  /// A server asked for a client certificate (mutual TLS).
  @async
  ClientCertResponseMessage onClientCertRequest(
    int webViewId,
    ClientCertRequestMessage request,
  );

  /// The page started a download. The WebView does not save the file.
  void onDownloadStart(int webViewId, DownloadRequestMessage request);

  /// The page asked for camera, microphone or location access.
  @async
  PermissionDecisionMessage onPermissionRequest(
    int webViewId,
    PermissionRequestMessage request,
  );

  /// The page opened a JavaScript dialog (`alert`, `confirm` or `prompt`).
  /// The page is blocked until this completes.
  @async
  JsDialogResultMessage onJsDialog(
    int webViewId,
    JsDialogRequestMessage request,
  );

  /// A request to a scheme listed in `interceptSchemes`. Null lets the
  /// request through (Android) or fails it (iOS, where custom schemes have no
  /// network fallback). Android blocks a WebView IO thread, not the main
  /// thread, until this completes.
  @async
  InterceptResponseMessage? onInterceptRequest(
    int webViewId,
    InterceptRequestMessage request,
  );

  /// A page called a JavaScript handler. `argsJson` is the JSON-encoded
  /// argument list; the result is the JSON-encoded return value. Throwing
  /// rejects the page's promise.
  @async
  String onJavaScriptHandlerCall(
    int webViewId,
    String handlerName,
    String argsJson,
  );

  /// The page asked for a new window; the WebView did not load `url` itself.
  void onNewWindowRequest(int webViewId, String url);

  /// The in-app browser was dismissed, by the user or by `closeInAppBrowser`.
  void onInAppBrowserClosed(int webViewId);
}
