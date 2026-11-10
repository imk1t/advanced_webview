import 'dart:typed_data';

import 'package:advanced_webview/src/platform/messages.g.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [AdvancedWebViewHostApi] that records every call.
class FakeHostApi extends Fake implements AdvancedWebViewHostApi {
  final List<String> calls = [];
  final Map<int, CreationParamsMessage> created = {};
  String? nextJavaScriptResult;

  @override
  Future<void> create(CreationParamsMessage params) async {
    calls.add('create(${params.webViewId})');
    created[params.webViewId] = params;
  }

  @override
  Future<void> dispose(int webViewId) async => calls.add('dispose($webViewId)');

  @override
  Future<void> loadUrl(
    int webViewId,
    String url,
    Map<String, String> headers,
  ) async => calls.add('loadUrl($url, $headers)');

  @override
  Future<void> loadHtmlString(
    int webViewId,
    String html,
    String? baseUrl,
  ) async => calls.add('loadHtmlString($baseUrl)');

  @override
  Future<void> loadRequest(
    int webViewId,
    String url,
    HttpMethodMessage method,
    Map<String, String> headers,
    Uint8List? body,
  ) async => calls.add('loadRequest($method $url, $headers, ${body?.length})');

  @override
  Future<void> loadFlutterAsset(int webViewId, String key) async =>
      calls.add('loadFlutterAsset($key)');

  @override
  Future<void> loadFile(int webViewId, String path) async =>
      calls.add('loadFile($path)');

  @override
  Future<void> reload(int webViewId) async => calls.add('reload');

  @override
  Future<void> pause(int webViewId) async => calls.add('pause');

  @override
  Future<void> resume(int webViewId) async => calls.add('resume');

  @override
  Future<void> pauseTimers(int webViewId) async => calls.add('pauseTimers');

  @override
  Future<void> resumeTimers(int webViewId) async => calls.add('resumeTimers');

  @override
  Future<void> stopLoading(int webViewId) async => calls.add('stopLoading');

  @override
  Future<void> goBack(int webViewId) async => calls.add('goBack');

  @override
  Future<void> goForward(int webViewId) async => calls.add('goForward');

  @override
  Future<bool> canGoBack(int webViewId) async => true;

  @override
  Future<bool> canGoForward(int webViewId) async => false;

  @override
  Future<String?> getUrl(int webViewId) async => 'https://example.com/';

  @override
  Future<String?> getTitle(int webViewId) async => 'Example';

  @override
  Future<String?> evaluateJavaScript(int webViewId, String source) async {
    calls.add('evaluateJavaScript($source)');
    return nextJavaScriptResult;
  }

  @override
  Future<void> printPage(int webViewId, String? jobName) async =>
      calls.add('printPage($jobName)');

  Uint8List? nextState;
  bool nextRestoreResult = true;

  @override
  Future<Uint8List?> saveState(int webViewId) async {
    calls.add('saveState');
    return nextState;
  }

  @override
  Future<bool> restoreState(int webViewId, Uint8List state) async {
    calls.add('restoreState(${state.length})');
    return nextRestoreResult;
  }

  ScrollPositionMessage nextScrollPosition = ScrollPositionMessage(x: 0, y: 0);

  @override
  Future<void> scrollTo(int webViewId, double x, double y) async =>
      calls.add('scrollTo($x, $y)');

  double zoomScale = 1;

  @override
  Future<void> zoomBy(int webViewId, double factor) async {
    calls.add('zoomBy($factor)');
    zoomScale *= factor;
  }

  @override
  Future<void> setZoomScale(int webViewId, double scale) async {
    calls.add('setZoomScale($scale)');
    zoomScale = scale;
  }

  @override
  Future<double> getZoomScale(int webViewId) async {
    calls.add('getZoomScale');
    return zoomScale;
  }

  @override
  Future<void> scrollBy(int webViewId, double dx, double dy) async =>
      calls.add('scrollBy($dx, $dy)');

  @override
  Future<ScrollPositionMessage> getScrollPosition(int webViewId) async {
    calls.add('getScrollPosition');
    return nextScrollPosition;
  }

  FindResultMessage nextFindResult = FindResultMessage(found: false);

  @override
  Future<FindResultMessage> findText(
    int webViewId,
    String query,
    bool forward,
  ) async {
    calls.add('findText($query, $forward)');
    return nextFindResult;
  }

  @override
  Future<void> clearMatches(int webViewId) async => calls.add('clearMatches');

  Uint8List? nextScreenshot;

  Uint8List pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);

  @override
  Future<Uint8List> createPdf(int webViewId) async {
    calls.add('createPdf');
    return pdf;
  }

  @override
  Future<Uint8List?> takeScreenshot(int webViewId) async {
    calls.add('takeScreenshot');
    return nextScreenshot;
  }

  @override
  Future<void> updateSettings(
    int webViewId,
    WebViewSettingsMessage settings,
  ) async => calls.add('updateSettings(js: ${settings.javaScriptEnabled})');

  final Map<String, CookieMessage> cookies = {};

  @override
  Future<void> setCookie(int webViewId, CookieMessage cookie) async {
    calls.add('setCookie(${cookie.name})');
    cookies['${cookie.domain}|${cookie.name}'] = cookie;
  }

  @override
  Future<List<CookieMessage>> getCookies(int webViewId, String url) async {
    calls.add('getCookies($url)');
    return cookies.values.toList();
  }

  final List<List<WebsiteDataTypeMessage>> clearedWebsiteData = [];

  @override
  Future<void> clearWebsiteData(
    int webViewId,
    List<WebsiteDataTypeMessage> types,
  ) async {
    calls.add('clearWebsiteData');
    clearedWebsiteData.add(types);
  }

  @override
  Future<void> deleteCookie(int webViewId, String url, String name) async {
    calls.add('deleteCookie($url, $name)');
    cookies.removeWhere((_, cookie) => cookie.name == name);
  }

  @override
  Future<void> deleteCookies(int webViewId, String url) async {
    calls.add('deleteCookies($url)');
    cookies.clear();
  }

  @override
  Future<void> clearCookies(int webViewId) async {
    calls.add('clearCookies');
    cookies.clear();
  }

  final List<UserScriptMessage> userScripts = [];

  @override
  Future<void> addUserScript(int webViewId, UserScriptMessage script) async {
    calls.add('addUserScript');
    userScripts.add(script);
  }

  @override
  Future<void> removeAllUserScripts(int webViewId) async {
    calls.add('removeAllUserScripts');
    userScripts.clear();
  }

  final Map<int, InAppBrowserParamsMessage> inAppBrowsers = {};
  Object? openInAppBrowserError;

  @override
  Future<void> openInAppBrowser(InAppBrowserParamsMessage params) async {
    calls.add('openInAppBrowser(${params.webViewId})');
    final error = openInAppBrowserError;
    if (error != null) throw error;
    inAppBrowsers[params.webViewId] = params;
  }

  @override
  Future<void> closeInAppBrowser(int webViewId) async {
    calls.add('closeInAppBrowser($webViewId)');
    inAppBrowsers.remove(webViewId);
  }
}
