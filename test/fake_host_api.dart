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
  Future<void> reload(int webViewId) async => calls.add('reload');

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
  Future<void> updateSettings(
    int webViewId,
    WebViewSettingsMessage settings,
  ) async => calls.add('updateSettings(js: ${settings.javaScriptEnabled})');
}
