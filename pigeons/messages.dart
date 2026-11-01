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
class WebViewSettingsMessage {
  WebViewSettingsMessage({
    required this.javaScriptEnabled,
    required this.mediaPlaybackRequiresUserGesture,
    required this.allowsInlineMediaPlayback,
    required this.supportZoom,
    required this.transparentBackground,
    required this.passkeysEnabled,
    this.userAgent,
  });

  bool javaScriptEnabled;
  bool mediaPlaybackRequiresUserGesture;

  /// iOS only. Ignored on Android.
  bool allowsInlineMediaPlayback;

  /// Android only. Ignored on iOS.
  bool supportZoom;
  bool transparentBackground;

  /// Android only. Ignored on iOS, where WebAuthn is governed by entitlements.
  bool passkeysEnabled;
  String? userAgent;
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
    required this.hasNavigationDelegate,
    required this.hasNewWindowDelegate,
    required this.userScripts,
  });

  int webViewId;
  WebViewSettingsMessage settings;

  /// Names exposed to JS as `window.<name>.postMessage(String)`.
  List<String> javaScriptChannelNames;

  /// Handlers the page can call with `window.advancedWebView.callHandler`.
  /// The bridge is only installed when this is not empty.
  List<String> javaScriptHandlerNames;

  /// When false, native code never round-trips navigation decisions to Dart.
  bool hasNavigationDelegate;

  /// When false, `window.open` and `target="_blank"` load in the same WebView
  /// and never round-trip to Dart.
  bool hasNewWindowDelegate;

  /// Scripts injected into every page loaded after creation.
  List<UserScriptMessage> userScripts;
}

class NavigationRequestMessage {
  NavigationRequestMessage({required this.url, required this.isMainFrame});

  String url;
  bool isMainFrame;
}

enum NavigationDecisionMessage { navigate, prevent }

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

  void reload(int webViewId);

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

  void updateSettings(int webViewId, WebViewSettingsMessage settings);

  @async
  void setCookie(int webViewId, CookieMessage cookie);

  /// Returns the cookies the WebView would send to `url`.
  @async
  List<CookieMessage> getCookies(int webViewId, String url);

  @async
  void clearCookies(int webViewId);

  /// Registers a script for pages loaded from now on.
  void addUserScript(int webViewId, UserScriptMessage script);

  void removeAllUserScripts(int webViewId);
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

  void onReceivedError(int webViewId, WebResourceErrorMessage error);

  @async
  NavigationDecisionMessage shouldOverrideUrlLoading(
    int webViewId,
    NavigationRequestMessage request,
  );

  void onJavaScriptMessage(int webViewId, String channelName, String message);

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
}
