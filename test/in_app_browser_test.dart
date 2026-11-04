import 'dart:ui';

import 'package:advanced_webview/advanced_webview.dart';
import 'package:advanced_webview/src/platform/event_dispatcher.dart';
import 'package:advanced_webview/src/platform/messages.g.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_host_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHostApi hostApi;
  late WebViewEventDispatcher dispatcher;
  late List<String> events;
  late AdvancedInAppBrowser browser;

  setUp(() {
    hostApi = FakeHostApi();
    dispatcher = WebViewEventDispatcher();
    events = [];
    browser = AdvancedInAppBrowser(
      hostApi: hostApi,
      dispatcher: dispatcher,
      onOpened: () => events.add('opened'),
      onClosed: () => events.add('closed'),
      onPageStarted: (url) => events.add('started $url'),
      onPageFinished: (url) => events.add('finished $url'),
      onLoadError: (error) => events.add('error ${error.errorCode}'),
    );
  });

  int openedId() => hostApi.inAppBrowsers.keys.single;

  test('open creates a WebView, presents it and loads the URL', () async {
    await browser.open(Uri.parse('https://example.com/a'));

    final id = openedId();
    expect(hostApi.created[id], isNotNull);
    expect(
      hostApi.calls,
      containsAllInOrder([
        'create($id)',
        'openInAppBrowser($id)',
        'loadUrl(https://example.com/a, {})',
      ]),
    );
    expect(browser.isOpened, isTrue);
    expect(events, ['opened']);
  });

  test('options are sent to the platform', () async {
    await browser.open(
      Uri.parse('https://example.com'),
      options: const InAppBrowserOptions(
        toolbarColor: Color(0xFF123456),
        toolbarTitle: 'Docs',
        showUrl: true,
        showNavigationButtons: false,
        closeButtonLabel: 'Back to app',
        settings: WebViewSettings(javaScriptEnabled: false),
      ),
    );

    final params = hostApi.inAppBrowsers[openedId()]!;
    expect(params.toolbarColor, 0xFF123456);
    expect(params.toolbarTitle, 'Docs');
    expect(params.showUrl, isTrue);
    expect(params.showNavigationButtons, isFalse);
    expect(params.closeButtonLabel, 'Back to app');
    expect(
      hostApi.created[params.webViewId]!.settings.javaScriptEnabled,
      false,
    );
  });

  test('defaults show the navigation buttons and no URL', () async {
    await browser.open(Uri.parse('https://example.com'));

    final params = hostApi.inAppBrowsers[openedId()]!;
    expect(params.showUrl, isFalse);
    expect(params.showNavigationButtons, isTrue);
    expect(params.toolbarColor, isNull);
    expect(params.toolbarTitle, isNull);
  });

  test('open twice throws', () async {
    await browser.open(Uri.parse('https://example.com'));

    expect(
      () => browser.open(Uri.parse('https://example.com')),
      throwsStateError,
    );
  });

  test('a failed open disposes the WebView and can be retried', () async {
    hostApi.openInAppBrowserError = StateError('not-attached');

    await expectLater(
      browser.open(Uri.parse('https://example.com')),
      throwsStateError,
    );

    expect(browser.isOpened, isFalse);
    expect(hostApi.calls.last, startsWith('dispose('));
    hostApi.openInAppBrowserError = null;
    await browser.open(Uri.parse('https://example.com'));
    expect(browser.isOpened, isTrue);
  });

  test('close dismisses the browser and reports onClosed once', () async {
    await browser.open(Uri.parse('https://example.com'));
    final id = openedId();

    await browser.close();
    dispatcher.onInAppBrowserClosed(id);

    expect(
      hostApi.calls,
      containsAllInOrder(['closeInAppBrowser($id)', 'dispose($id)']),
    );
    expect(browser.isOpened, isFalse);
    expect(events, ['opened', 'closed']);
  });

  test('close does nothing when not open', () async {
    await browser.close();

    expect(hostApi.calls, isEmpty);
    expect(events, isEmpty);
  });

  test(
    'a native dismissal disposes the WebView and reports onClosed',
    () async {
      await browser.open(Uri.parse('https://example.com'));
      final id = openedId();

      dispatcher.onInAppBrowserClosed(id);
      await Future<void>.delayed(Duration.zero);

      expect(browser.isOpened, isFalse);
      expect(hostApi.calls, contains('dispose($id)'));
      expect(events, ['opened', 'closed']);
    },
  );

  test('can be opened again after closing', () async {
    await browser.open(Uri.parse('https://example.com'));
    await browser.close();
    await browser.open(Uri.parse('https://example.org'));

    expect(browser.isOpened, isTrue);
    expect(events, ['opened', 'closed', 'opened']);
  });

  test('page events and main-frame errors are forwarded', () async {
    await browser.open(Uri.parse('https://example.com'));
    final id = openedId();

    dispatcher.onPageStarted(id, 'https://example.com/');
    dispatcher.onPageFinished(id, 'https://example.com/');
    dispatcher.onReceivedError(
      id,
      WebResourceErrorMessage(errorCode: -2, message: 'x', isMainFrame: true),
    );
    dispatcher.onReceivedError(
      id,
      WebResourceErrorMessage(errorCode: -3, message: 'x', isMainFrame: false),
    );

    expect(events, [
      'opened',
      'started https://example.com/',
      'finished https://example.com/',
      'error -2',
    ]);
  });

  test('loadUrl and evaluateJavaScript need an open browser', () async {
    expect(() => browser.loadUrl(Uri.parse('https://a.b')), throwsStateError);
    expect(() => browser.evaluateJavaScript('1'), throwsStateError);

    await browser.open(Uri.parse('https://example.com'));
    hostApi.nextJavaScriptResult = '42';
    await browser.loadUrl(Uri.parse('https://example.org'));

    expect(await browser.evaluateJavaScript('21 * 2'), 42);
    expect(hostApi.calls, contains('loadUrl(https://example.org, {})'));
  });
}
