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
    dartPackageName: 'flutter_mobile_webview',
    kotlinOut:
        'android/src/main/kotlin/dev/k1t/flutter_mobile_webview/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.k1t.flutter_mobile_webview'),
    swiftOut: 'ios/flutter_mobile_webview/Sources/flutter_mobile_webview/Messages.g.swift',
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
    this.userAgent,
  });

  bool javaScriptEnabled;
  bool mediaPlaybackRequiresUserGesture;

  /// iOS only. Ignored on Android.
  bool allowsInlineMediaPlayback;

  /// Android only. Ignored on iOS.
  bool supportZoom;
  bool transparentBackground;
  String? userAgent;
}

class CreationParamsMessage {
  CreationParamsMessage({
    required this.webViewId,
    required this.settings,
    required this.javaScriptChannelNames,
    required this.hasNavigationDelegate,
  });

  int webViewId;
  WebViewSettingsMessage settings;

  /// Names exposed to JS as `window.<name>.postMessage(String)`.
  List<String> javaScriptChannelNames;

  /// When false, native code never round-trips navigation decisions to Dart.
  bool hasNavigationDelegate;
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

// ---------------------------------------------------------------------------
// Dart -> native
// ---------------------------------------------------------------------------

@HostApi()
abstract class MobileWebViewHostApi {
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
}

// ---------------------------------------------------------------------------
// native -> Dart
// ---------------------------------------------------------------------------

@FlutterApi()
abstract class MobileWebViewFlutterApi {
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
}
