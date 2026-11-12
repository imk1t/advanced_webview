import 'package:advanced_webview/advanced_webview.dart';
import 'package:advanced_webview/src/platform/event_dispatcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_host_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHostApi hostApi;
  late WebViewEventDispatcher dispatcher;
  late List<String> events;
  late AdvancedSystemBrowser browser;

  setUp(() {
    hostApi = FakeHostApi();
    dispatcher = WebViewEventDispatcher();
    events = [];
    browser = AdvancedSystemBrowser(
      hostApi: hostApi,
      dispatcher: dispatcher,
      onClosed: () => events.add('closed'),
    );
  });

  test('isAvailable asks the platform', () async {
    expect(await browser.isAvailable(), isTrue);
    hostApi.systemBrowserAvailable = false;
    expect(await browser.isAvailable(), isFalse);
  });

  test('open passes the URL and toolbar colour to native', () async {
    await browser.open(
      Uri.parse('https://example.com/login?x=1'),
      options: const SystemBrowserOptions(toolbarColor: Color(0xFF112233)),
    );

    final params = hostApi.systemBrowsers.single;
    expect(params.url, 'https://example.com/login?x=1');
    expect(params.toolbarColor, 0xFF112233);
    expect(events, isEmpty);
  });

  test('open rejects URLs that are not http or https', () async {
    for (final url in ['file:///etc/passwd', 'myapp://x', '/relative']) {
      await expectLater(
        browser.open(Uri.parse(url)),
        throwsArgumentError,
        reason: url,
      );
    }
    expect(hostApi.systemBrowsers, isEmpty);
  });

  test('onClosed fires once for the session that was dismissed', () async {
    await browser.open(Uri.parse('https://example.com/a'));
    final id = hostApi.systemBrowsers.single.sessionId;

    dispatcher.onSystemBrowserClosed(id + 1000);
    expect(events, isEmpty);

    dispatcher.onSystemBrowserClosed(id);
    dispatcher.onSystemBrowserClosed(id);
    expect(events, ['closed']);
  });

  test('a failed open does not leave a listener behind', () async {
    hostApi.openSystemBrowserError = PlatformException(code: 'unavailable');
    await expectLater(
      browser.open(Uri.parse('https://example.com/')),
      throwsA(isA<PlatformException>()),
    );

    hostApi.openSystemBrowserError = null;
    await browser.open(Uri.parse('https://example.com/'));
    final id = hostApi.systemBrowsers.single.sessionId;
    dispatcher.onSystemBrowserClosed(id - 1);
    expect(events, isEmpty);
  });
}
