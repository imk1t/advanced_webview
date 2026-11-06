// Runs on a real device or simulator: `flutter test integration_test`.
//
// These tests exercise the native implementations end to end, so they are the
// place to pin down behaviour that must match on Android and iOS.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:advanced_webview/advanced_webview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _timeout = Duration(seconds: 20);
const _baseUrl = 'https://advanced-webview.test/';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('in-app browser opens, runs JavaScript and closes', (
    tester,
  ) async {
    final events = <String>[];
    final browser = AdvancedInAppBrowser(
      onOpened: () => events.add('opened'),
      onClosed: () => events.add('closed'),
      onPageFinished: (_) => events.add('finished'),
    );
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));

    await browser.open(
      Uri.dataFromString(
        '<html><head><title>browser</title></head><body></body></html>',
        mimeType: 'text/html',
        encoding: utf8,
      ),
      options: const InAppBrowserOptions(showUrl: true),
    );
    await _pumpUntil(tester, () => events.contains('finished'));

    expect(browser.isOpened, isTrue);
    expect(await browser.evaluateJavaScript('document.title'), 'browser');

    await browser.close();
    await _pumpUntil(tester, () => events.contains('closed'));

    expect(browser.isOpened, isFalse);
    expect(events.first, 'opened');
    expect(events.where((e) => e == 'closed'), hasLength(1));
  });

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

  testWidgets('JavaScript dialogs are answered by the app', (tester) async {
    final seen = <JsDialogRequest>[];
    final harness = _Harness(
      onJsDialog: (request) {
        seen.add(request);
        return switch (request.type) {
          JsDialogType.alert => const JsDialogResponse.accept(),
          JsDialogType.confirm => const JsDialogResponse.dismiss(),
          JsDialogType.prompt => const JsDialogResponse.accept(text: 'Bob'),
        };
      },
    );
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml('<html><body></body></html>');

    expect(
      await harness.controller.runJavaScriptReturningResult(
        '(alert("a"), [confirm("c"), prompt("p", "Ann")])',
      ),
      [false, 'Bob'],
    );
    expect(seen.map((r) => r.type), JsDialogType.values);
    expect(seen.map((r) => r.message), ['a', 'c', 'p']);
    expect(seen.last.defaultText, 'Ann');
    expect(seen.first.defaultText, isNull);
  });

  testWidgets('clearWebsiteData removes the selected storage', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.show(tester);
    await harness.loadHtml('<html><body></body></html>');
    Future<Object?> read() => harness.controller.runJavaScriptReturningResult(
      '[localStorage.getItem("k"), sessionStorage.getItem("k")]',
    );

    await harness.controller.runJavaScript(
      'localStorage.setItem("k", "v"); sessionStorage.setItem("k", "v");',
    );
    expect(await read(), ['v', 'v']);

    // Clearing only the cache leaves storage alone.
    await harness.controller.clearWebsiteData(types: {WebsiteDataType.cache});
    expect(await read(), ['v', 'v']);

    await harness.controller.clearWebsiteData();
    await harness.loadHtml('<html><body></body></html>');
    expect((await read() as List)[0], isNull);
  });

  testWidgets('HTTP error statuses of the main page are reported', (
    tester,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response
        ..statusCode = request.uri.path == '/ok' ? 200 : 404
        ..headers.contentType = ContentType.html
        ..write('<html><body>${request.uri.path}</body></html>')
        ..close();
    });
    final base = 'http://127.0.0.1:${server.port}';
    final errors = <HttpError>[];
    final harness = _Harness(onHttpError: errors.add);
    addTearDown(harness.dispose);
    await harness.show(tester);

    // Android also reports sub-resources (the favicon request 404s here).
    List<HttpError> mainFrame() => errors.where((e) => e.isMainFrame).toList();

    await harness.controller.loadUrl('$base/ok');
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(mainFrame(), isEmpty);

    await harness.controller.loadUrl('$base/missing');
    await _pumpUntil(tester, () => mainFrame().isNotEmpty);

    expect(mainFrame().single.statusCode, 404);
    expect(mainFrame().single.url, '$base/missing');
  });

  testWidgets('loads a Flutter asset', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.show(tester);

    final finished = harness.expectPageFinished();
    await harness.controller.loadFlutterAsset('assets/hello.html');
    await finished;

    expect(await harness.controller.title(), 'hello asset');
  });

  testWidgets('loads a local file', (tester) async {
    final dir = await Directory.systemTemp.createTemp('advanced_webview');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/page.html')
      ..writeAsStringSync('<html><head><title>from file</title></head></html>');
    final harness = _Harness(
      settings: const WebViewSettings(
        android: AndroidWebViewSettings(allowFileAccess: true),
      ),
    );
    addTearDown(harness.dispose);
    await harness.show(tester);

    final finished = harness.expectPageFinished();
    await harness.controller.loadFile(file.path);
    await finished;

    expect(await harness.controller.title(), 'from file');
  });

  testWidgets('loadRequest sends a POST body', (tester) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      request.response
        ..headers.contentType = ContentType.html
        ..write(
          '<html><head><title>${request.method} $body</title></head></html>',
        )
        ..close();
    });
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.show(tester);

    final finished = harness.expectPageFinished();
    await harness.controller.loadRequest(
      'http://127.0.0.1:${server.port}/submit',
      method: WebViewHttpMethod.post,
      body: Uint8List.fromList(utf8.encode('a=1&b=2')),
    );
    await finished;

    expect(await harness.controller.title(), 'POST a=1&b=2');
  });

  testWidgets('custom scheme requests are answered by the app', (tester) async {
    final requests = <String>[];
    final harness = _Harness(
      interceptSchemes: ['app'],
      onInterceptRequest: (request) {
        requests.add(request.url);
        if (request.url.endsWith('/data.js')) {
          return InterceptResponse.text(
            'document.title = "from dart";',
            mimeType: 'text/javascript',
          );
        }
        // A script element, because Android's Chromium refuses fetch() to a
        // custom scheme before the request reaches the callback.
        return InterceptResponse.text(
          '<html><body><script src="app://host/data.js"></script></body></html>',
        );
      },
    );
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.controller.loadUrl('app://host/index.html');
    await _pumpUntilAsync(
      tester,
      () async => await harness.controller.title() == 'from dart',
    );

    expect(await harness.controller.title(), 'from dart');
    expect(requests, ['app://host/index.html', 'app://host/data.js']);
  });

  testWidgets('console output is reported with its level', (tester) async {
    final messages = <WebViewConsoleMessage>[];
    final harness = _Harness(onConsoleMessage: messages.add);
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml(
      '<html><body><iframe srcdoc="<script>console.log(\'from frame\')</script>">'
      '</iframe></body></html>',
    );
    await harness.controller.runJavaScript('''
      console.debug('d');
      console.info('i');
      console.log('a', 1, 'b');
      console.warn('w');
      console.error('e');
    ''');
    await _pumpUntil(tester, () => messages.length >= 6);

    String? levelOf(String text) =>
        messages.where((m) => m.message == text).firstOrNull?.level.name;
    expect(levelOf('a 1 b'), 'log');
    expect(levelOf('w'), 'warning');
    expect(levelOf('e'), 'error');
    // Android may map debug and info onto neighbouring levels.
    expect(levelOf('d'), isNotNull);
    expect(levelOf('i'), isNotNull);
    expect(levelOf('from frame'), 'log');
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

  testWidgets('JavaScript handlers return values and reject on errors', (
    tester,
  ) async {
    final results = <String>[];
    final harness = _Harness(
      javaScriptChannels: {'Out': results.add},
      javaScriptHandlers: {
        'sum': (args) => args.fold<num>(0, (a, b) => a + (b as num)),
        'echo': (args) async => {'args': args},
        'fail': (_) => throw StateError('boom'),
      },
    );
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml('<html><body></body></html>');

    // runJavaScript does not await promises, so report through a channel.
    // `void` keeps WKWebView from rejecting the Promise as an unsupported result.
    await harness.controller.runJavaScript('''
      void (async () => {
        const total = await window.advanced_webview.callHandler('sum', 1, 2, 3);
        const echoed = await window.advanced_webview.callHandler('echo', 'a', {b: [1]});
        let error = null;
        try { await window.advanced_webview.callHandler('fail'); }
        catch (e) { error = String(e.message); }
        Out.postMessage(JSON.stringify({total, echoed, error}));
      })();
    ''');
    await _pumpUntil(tester, () => results.isNotEmpty);

    final result = jsonDecode(results.single) as Map<String, Object?>;
    expect(result['total'], 6);
    expect(result['echoed'], {
      'args': [
        'a',
        {
          'b': [1],
        },
      ],
    });
    expect(result['error'], contains('boom'));
  });

  testWidgets('downloads are reported instead of saved', (tester) async {
    final downloads = <DownloadRequest>[];
    final harness = _Harness(onDownloadStart: downloads.add);
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml(
      '<html><body><a id="a" href="data:text/plain;base64,aGk=" '
      'download="hi.txt">get</a></body></html>',
    );
    await harness.controller.runJavaScript(
      'document.getElementById("a").click()',
    );
    await _pumpUntil(tester, () => downloads.isNotEmpty);

    expect(downloads.single.url, startsWith('data:text/plain'));
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

  testWidgets('user scripts run at document start and end', (tester) async {
    final harness = _Harness(
      userScripts: const [
        UserScript(source: 'window.startState = document.readyState;'),
        UserScript(
          source: 'window.endBody = document.body.textContent;',
          injectionTime: UserScriptInjectionTime.atDocumentEnd,
        ),
      ],
    );
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml('<html><body>content</body></html>');

    expect(
      await harness.controller.runJavaScriptReturningResult(
        'window.startState',
      ),
      'loading',
    );
    expect(
      await harness.controller.runJavaScriptReturningResult('window.endBody'),
      'content',
    );

    // Removed scripts no longer run on later loads.
    await harness.controller.removeAllUserScripts();
    await harness.loadHtml('<html><body>again</body></html>');
    expect(
      await harness.controller.runJavaScriptReturningResult(
        'window.startState',
      ),
      isNull,
    );
  });

  testWidgets('window.open is reported to onNewWindow instead of loading', (
    tester,
  ) async {
    final urls = <String>[];
    final harness = _Harness(onNewWindow: urls.add);
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml('<html><body>start</body></html>');
    await harness.controller.runJavaScript('window.open("${_baseUrl}popup");');
    await _pumpUntil(tester, () => urls.isNotEmpty);

    expect(urls, ['${_baseUrl}popup']);
    expect(harness.startedUrls.where((u) => u.endsWith('popup')), isEmpty);
  });

  testWidgets('window.open loads in the same WebView without onNewWindow', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml('<html><body>start</body></html>');
    await harness.controller.runJavaScript('window.open("${_baseUrl}popup");');
    await _pumpUntil(
      tester,
      () => harness.startedUrls.contains('${_baseUrl}popup'),
    );
  });

  testWidgets('takeScreenshot returns a PNG of the visible page', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml('<html><body><h1>shot</h1></body></html>');
    await harness.waitForSize(tester);
    final png = await harness.controller.takeScreenshot();

    expect(png, isNotNull);
    expect(png!.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);
  });

  testWidgets('zoomBy and setZoomScale change the zoom scale', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml(
      '<html><head><meta name="viewport" content="width=device-width, '
      'initial-scale=1, maximum-scale=5"></head>'
      '<body style="height:3000px">zoom</body></html>',
    );
    await harness.waitForSize(tester);
    final before = await harness.controller.getZoomScale();
    expect(before, greaterThan(0));

    // Android ignores zoom requests until the page has been drawn.
    await tester.pump(const Duration(seconds: 3));
    await harness.controller.zoomBy(2);
    await _pumpUntilAsync(
      tester,
      () async => await harness.controller.getZoomScale() > before * 1.5,
    );

    await harness.controller.setZoomScale(before);
    await _pumpUntilAsync(
      tester,
      () async => await harness.controller.getZoomScale() < before * 1.2,
    );
  });

  testWidgets('the favicon URL is read from the page', (tester) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response
        ..headers.contentType = ContentType.html
        ..write(
          request.uri.path == '/icon'
              ? '<html><head><link rel="shortcut icon" href="/custom.png">'
                    '</head><body>x</body></html>'
              : '<html><body>no icon</body></html>',
        )
        ..close();
    });
    final base = 'http://127.0.0.1:${server.port}';
    final icons = <String?>[];
    final harness = _Harness(onFaviconChanged: icons.add);
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.controller.loadUrl('$base/icon');
    await _pumpUntil(tester, () => icons.isNotEmpty);
    expect(icons.last, '$base/custom.png');

    icons.clear();
    await harness.controller.loadUrl('$base/plain');
    await _pumpUntil(tester, () => icons.isNotEmpty);
    expect(icons.last, '$base/favicon.ico');
  });

  testWidgets('pause and resume leave the page working', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml(
      '<html><body><script>window.ticks = 0; '
      'setInterval(function () { window.ticks++; }, 50);</script></body></html>',
    );
    await harness.waitForSize(tester);

    await harness.controller.pause();
    await harness.controller.resume();
    await harness.controller.pauseTimers();
    await harness.controller.resumeTimers();

    // Timers run again after resumeTimers (and were never stopped on iOS).
    await _pumpUntilAsync(tester, () async {
      final ticks = await harness.controller.runJavaScriptReturningResult(
        'window.ticks',
      );
      return (ticks as num) > 2;
    });
  });

  testWidgets('createPdf renders the page to a PDF', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml('<html><body><h1>pdf</h1></body></html>');
    await harness.waitForSize(tester);
    final pdf = await harness.controller.createPdf();

    expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
    expect(pdf.length, greaterThan(500));
  });

  testWidgets('findText finds text and clearMatches removes the highlight', (
    tester,
  ) async {
    final updates = <(int, int, bool)>[];
    final harness = _Harness(
      onFindResult: (index, count, done) => updates.add((index, count, done)),
    );
    addTearDown(harness.dispose);

    await harness.show(tester);
    await harness.loadHtml('<html><body><p>alpha beta alpha</p></body></html>');

    final hit = await harness.controller.findText('alpha');
    final miss = await harness.controller.findText('zzz');
    await harness.controller.clearMatches();

    expect(hit.found, isTrue);
    expect(hit.matchCount, 2);
    expect(hit.activeMatchIndex, 0);
    expect(miss.found, isFalse);
    // Both platforms end with a final update for the hit.
    expect(updates.where((u) => u.$3 && u.$2 == 2), isNotEmpty);
  });

  testWidgets('hitTest finds the link and image under a point', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.show(tester);
    await harness.loadHtml(
      '<html><body style="margin:0">'
      '<a href="https://example.com/target" style="display:block;height:50px">link</a>'
      '<img src="data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==" '
      'style="display:block;width:50px;height:50px">'
      '</body></html>',
    );

    await harness.waitForSize(tester);

    final link = await harness.controller.hitTest(const Offset(10, 10));
    final image = await harness.controller.hitTest(const Offset(10, 70));
    final none = await harness.controller.hitTest(const Offset(10, 400));

    expect(link.type, WebViewHitTestType.link);
    expect(link.linkUrl, 'https://example.com/target');
    expect(image.type, WebViewHitTestType.image);
    expect(image.imageUrl, startsWith('data:image/gif'));
    expect(none.type, WebViewHitTestType.none);
  });

  testWidgets('saveState from one WebView is accepted by another', (
    tester,
  ) async {
    final source = _Harness();
    addTearDown(source.dispose);
    await source.show(tester);
    await source.loadHtml('<html><body><p>saved</p></body></html>');

    final state = await source.controller.saveState();

    expect(state, isNotNull);
    expect(state, isNotEmpty);
    final target = _Harness();
    addTearDown(target.dispose);
    await target.show(tester);
    expect(await target.controller.restoreState(state!), isTrue);
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
    Map<String, JavaScriptHandler> javaScriptHandlers = const {},
    NavigationRequestCallback? onNavigationRequest,
    List<UserScript> userScripts = const [],
    NewWindowCallback? onNewWindow,
    DownloadStartCallback? onDownloadStart,
    ConsoleMessageCallback? onConsoleMessage,
    JsDialogCallback? onJsDialog,
    HttpErrorCallback? onHttpError,
    FindResultCallback? onFindResult,
    FaviconChangedCallback? onFaviconChanged,
    List<String> interceptSchemes = const [],
    InterceptRequestCallback? onInterceptRequest,
    WebViewSettings settings = const WebViewSettings(),
  }) {
    controller = AdvancedWebViewController(
      settings: settings,
      javaScriptChannels: javaScriptChannels,
      javaScriptHandlers: javaScriptHandlers,
      userScripts: userScripts,
      onNavigationRequest: onNavigationRequest,
      onNewWindow: onNewWindow,
      onDownloadStart: onDownloadStart,
      onConsoleMessage: onConsoleMessage,
      onJsDialog: onJsDialog,
      onHttpError: onHttpError,
      onFindResult: onFindResult,
      onFaviconChanged: onFaviconChanged,
      interceptSchemes: interceptSchemes,
      onInterceptRequest: onInterceptRequest,
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

  /// Completes when the next page finishes loading; start it before the load.
  Future<void> expectPageFinished() {
    final finished = _pageFinished = Completer<void>();
    return finished.future.timeout(_timeout);
  }

  /// Loads [html] at [_baseUrl] and waits for the page to finish.
  Future<void> loadHtml(String html) async {
    final finished = _pageFinished = Completer<void>();
    await controller.loadHtmlString(html, baseUrl: _baseUrl);
    await finished.future.timeout(_timeout);
  }

  /// The platform view gets its size asynchronously; wait until the page has a viewport.
  Future<void> waitForSize(WidgetTester tester) => _pumpUntilAsync(
    tester,
    () async =>
        await controller.runJavaScriptReturningResult('window.innerWidth') != 0,
  );

  Future<void> dispose() => controller.dispose();
}

/// Like [_pumpUntil] for a condition that has to be awaited.
Future<void> _pumpUntilAsync(
  WidgetTester tester,
  Future<bool> Function() condition,
) async {
  final deadline = DateTime.now().add(_timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within $_timeout');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
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
