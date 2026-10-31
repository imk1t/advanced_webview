// Runs on a real device or simulator: `flutter test integration_test`.
//
// These tests exercise the native implementations end to end, so they are the
// place to pin down behaviour that must match on Android and iOS.
import 'dart:async';

import 'package:advanced_webview/advanced_webview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _timeout = Duration(seconds: 20);
const _baseUrl = 'https://advanced-webview.test/';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads HTML, evaluates JS and receives channel messages', (
    tester,
  ) async {
    final messages = <String>[];
    final harness = _Harness(javaScriptChannels: {'Echo': messages.add});
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml(
      '<html><head><title>hello</title></head><body></body></html>',
    );

    expect(await harness.controller.title(), 'hello');
    expect(await harness.controller.runJavaScriptReturningResult('1 + 2'), 3);
    expect(
      await harness.controller.runJavaScriptReturningResult('({a: [1, "b"]})'),
      {
        'a': [1, 'b'],
      },
    );
    expect(
      await harness.controller.runJavaScriptReturningResult('"text"'),
      'text',
    );
    expect(
      await harness.controller.runJavaScriptReturningResult('undefined'),
      isNull,
    );
    expect(
      await harness.controller.runJavaScriptReturningResult('null'),
      isNull,
    );

    await harness.controller.runJavaScript('Echo.postMessage("hi")');
    await _pumpUntil(tester, () => messages.isNotEmpty);
    expect(messages, ['hi']);
  });

  testWidgets('JavaScript channels are routed to the owning controller', (
    tester,
  ) async {
    final first = <String>[];
    final second = <String>[];
    final a = _Harness(javaScriptChannels: {'Echo': first.add});
    final b = _Harness(javaScriptChannels: {'Echo': second.add});
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Expanded(child: AdvancedWebView(controller: a.controller)),
            Expanded(child: AdvancedWebView(controller: b.controller)),
          ],
        ),
      ),
    );
    await a.loadHtml('<html><body>a</body></html>');
    await b.loadHtml('<html><body>b</body></html>');

    await a.controller.runJavaScript('Echo.postMessage("from a")');
    await b.controller.runJavaScript('Echo.postMessage("from b")');
    await _pumpUntil(tester, () => first.isNotEmpty && second.isNotEmpty);

    expect(first, ['from a']);
    expect(second, ['from b']);
  });

  testWidgets('navigation delegate can prevent a main-frame navigation', (
    tester,
  ) async {
    final requests = <NavigationRequest>[];
    final harness = _Harness(
      onNavigationRequest: (request) {
        if (!request.url.endsWith('blocked')) {
          return NavigationDecision.navigate;
        }
        requests.add(request);
        return NavigationDecision.prevent;
      },
    );
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml('<html><body>start</body></html>');
    harness.startedUrls.clear();

    await harness.controller.runJavaScript(
      'window.location.href = "${_baseUrl}blocked";',
    );
    await _pumpUntil(tester, () => requests.isNotEmpty);
    // Give a wrongly allowed navigation time to start.
    await tester.pump(const Duration(seconds: 1));

    expect(requests.single.url, '${_baseUrl}blocked');
    expect(requests.single.isMainFrame, isTrue);
    expect(harness.startedUrls, isNot(contains('${_baseUrl}blocked')));
    expect(
      await harness.controller.runJavaScriptReturningResult(
        'document.body.innerText',
      ),
      'start',
    );
  });

  testWidgets('navigation delegate can allow a main-frame navigation', (
    tester,
  ) async {
    final requests = <String>[];
    final harness = _Harness(
      onNavigationRequest: (request) {
        requests.add(request.url);
        return NavigationDecision.navigate;
      },
    );
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml('<html><body>start</body></html>');

    // The host does not resolve; only the start of the navigation matters.
    await harness.controller.runJavaScript(
      'window.location.href = "${_baseUrl}allowed";',
    );
    await _pumpUntil(
      tester,
      () => harness.startedUrls.contains('${_baseUrl}allowed'),
    );

    expect(requests, contains('${_baseUrl}allowed'));
  });

  testWidgets('app-initiated loads do not consult the navigation delegate', (
    tester,
  ) async {
    final requests = <String>[];
    final harness = _Harness(
      onNavigationRequest: (request) {
        requests.add(request.url);
        return NavigationDecision.prevent;
      },
    );
    addTearDown(harness.dispose);

    await harness.show(tester);
    // Both loads would time out if the delegate were asked and prevented them.
    await harness.loadHtml('<html><body>one</body></html>');
    await harness.loadHtml('<html><body>two</body></html>');
    await harness.controller.loadUrl('https://does-not-exist.invalid/');
    await _pumpUntil(tester, () => harness.errors.isNotEmpty);
    expect(requests, isEmpty);

    // A navigation started by the page is still reported.
    await harness.loadHtml('<html><body>three</body></html>');
    await harness.controller.runJavaScript(
      'window.location.href = "${_baseUrl}blocked";',
    );
    await _pumpUntil(tester, () => requests.isNotEmpty);
    expect(requests, ['${_baseUrl}blocked']);
  });

  testWidgets('reports main-frame load errors', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.controller.loadUrl('https://does-not-exist.invalid/');
    await _pumpUntil(tester, () => harness.errors.isNotEmpty);

    final error = harness.errors.first;
    expect(error.isMainFrame, isTrue);
    expect(error.errorCode, isNot(0));
    expect(error.message, isNotEmpty);
  });

  testWidgets('updateSettings applies a custom user agent', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.controller.updateSettings(
      const WebViewSettings(userAgent: 'advanced_webview-test'),
    );
    // A new document picks up the user agent on both platforms.
    await harness.loadHtml('<html><body></body></html>');

    expect(
      await harness.controller.runJavaScriptReturningResult(
        'navigator.userAgent',
      ),
      'advanced_webview-test',
    );
  });

  testWidgets('cookies can be set, read and cleared', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.controller.clearCookies();
    await harness.controller.setCookie(
      const WebViewCookie(
        name: 'visible',
        value: '1',
        domain: 'advanced-webview.test',
      ),
    );
    await harness.controller.setCookie(
      const WebViewCookie(
        name: 'hidden',
        value: '2',
        domain: 'advanced-webview.test',
        isHttpOnly: true,
      ),
    );

    final cookies = await harness.controller.getCookies(_baseUrl);
    expect(
      {for (final c in cookies) c.name: c.value},
      {'visible': '1', 'hidden': '2'},
    );

    // JavaScript only sees the cookie that is not HttpOnly.
    await harness.loadHtml('<html><body></body></html>');
    expect(
      await harness.controller.runJavaScriptReturningResult('document.cookie'),
      'visible=1',
    );

    await harness.controller.clearCookies();
    expect(await harness.controller.getCookies(_baseUrl), isEmpty);
  });

  testWidgets('the WebView outlives its widget', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml('<html><body></body></html>');
    await harness.controller.runJavaScript('window.marker = 42;');

    // Remove the platform view, then attach the same controller again.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    await harness.show(tester);

    expect(
      await harness.controller.runJavaScriptReturningResult('window.marker'),
      42,
    );
  });
}

/// One controller plus the events it received.
class _Harness {
  _Harness({
    Map<String, JavaScriptMessageCallback> javaScriptChannels = const {},
    NavigationRequestCallback? onNavigationRequest,
  }) {
    controller = AdvancedWebViewController(
      javaScriptChannels: javaScriptChannels,
      onNavigationRequest: onNavigationRequest,
      onPageStarted: startedUrls.add,
      onPageFinished: (url) {
        _pageFinished?.complete();
        _pageFinished = null;
      },
      onWebResourceError: errors.add,
    );
  }

  late final AdvancedWebViewController controller;
  final startedUrls = <String>[];
  final errors = <WebResourceError>[];
  Completer<void>? _pageFinished;

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AdvancedWebView(controller: controller)),
    );
    await controller.ready;
    await tester.pumpAndSettle();
  }

  /// Loads [html] at [_baseUrl] and waits for the page to finish.
  Future<void> loadHtml(String html) async {
    final finished = _pageFinished = Completer<void>();
    await controller.loadHtmlString(html, baseUrl: _baseUrl);
    await finished.future.timeout(_timeout);
  }

  Future<void> dispose() => controller.dispose();
}

/// Pumps frames until [condition] holds, failing after [_timeout].
Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(_timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within $_timeout');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}
