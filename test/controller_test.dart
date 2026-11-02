import 'dart:convert';

import 'package:advanced_webview/advanced_webview.dart';
import 'package:advanced_webview/src/platform/event_dispatcher.dart';
import 'package:advanced_webview/src/platform/messages.g.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_host_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHostApi hostApi;
  late WebViewEventDispatcher dispatcher;

  setUp(() {
    hostApi = FakeHostApi();
    dispatcher = WebViewEventDispatcher();
  });

  AdvancedWebViewController createController({
    Map<String, JavaScriptMessageCallback> javaScriptChannels = const {},
    Map<String, JavaScriptHandler> javaScriptHandlers = const {},
    String javaScriptHandlerObjectName = 'advanced_webview',
    List<UserScript> userScripts = const [],
    PageEventCallback? onPageFinished,
    WebResourceErrorCallback? onWebResourceError,
    NavigationRequestCallback? onNavigationRequest,
    NewWindowCallback? onNewWindow,
    PermissionRequestCallback? onPermissionRequest,
    DownloadStartCallback? onDownloadStart,
    SslErrorCallback? onSslError,
    HttpAuthCallback? onHttpAuthRequest,
  }) {
    return AdvancedWebViewController(
      hostApi: hostApi,
      dispatcher: dispatcher,
      javaScriptChannels: javaScriptChannels,
      javaScriptHandlers: javaScriptHandlers,
      javaScriptHandlerObjectName: javaScriptHandlerObjectName,
      userScripts: userScripts,
      onPageFinished: onPageFinished,
      onWebResourceError: onWebResourceError,
      onNavigationRequest: onNavigationRequest,
      onNewWindow: onNewWindow,
      onPermissionRequest: onPermissionRequest,
      onDownloadStart: onDownloadStart,
      onSslError: onSslError,
      onHttpAuthRequest: onHttpAuthRequest,
    );
  }

  group('creation', () {
    test('creates the native view with settings and channels', () async {
      final controller = createController(
        javaScriptChannels: {'Bridge': (_) {}},
        onNavigationRequest: (_) => NavigationDecision.navigate,
      );
      await controller.ready;

      final params = hostApi.created[controller.webViewId]!;
      expect(params.javaScriptChannelNames, ['Bridge']);
      expect(params.hasNavigationDelegate, isTrue);
      expect(params.settings.javaScriptEnabled, isTrue);
    });

    test('allocates a distinct id per controller', () {
      expect(createController().webViewId, isNot(createController().webViewId));
    });
  });

  group('commands', () {
    test('forward to the host API', () async {
      final controller = createController();
      await controller.loadUrl('https://a.dev', headers: {'X': '1'});
      await controller.reload();
      await controller.goBack();

      expect(hostApi.calls.skip(1), [
        'loadUrl(https://a.dev, {X: 1})',
        'reload',
        'goBack',
      ]);
      expect(await controller.canGoBack(), isTrue);
      expect(await controller.title(), 'Example');
    });

    test('decode JavaScript results from JSON', () async {
      final controller = createController();
      hostApi.nextJavaScriptResult = '{"a":[1,"b"]}';
      expect(await controller.runJavaScriptReturningResult('x'), {
        'a': [1, 'b'],
      });
      hostApi.nextJavaScriptResult = null;
      expect(await controller.runJavaScriptReturningResult('x'), isNull);
    });

    test('inspectable and back/forward gestures are passed to native', () {
      final defaults = const WebViewSettings().toMessage();
      expect(defaults.inspectable, isFalse);
      expect(defaults.allowsBackForwardNavigationGestures, isFalse);
      final message = const WebViewSettings(
        inspectable: true,
        allowsBackForwardNavigationGestures: true,
      ).toMessage();
      expect(message.inspectable, isTrue);
      expect(message.allowsBackForwardNavigationGestures, isTrue);
    });

    test('passkeysEnabled is passed to the native settings', () {
      expect(const WebViewSettings().toMessage().passkeysEnabled, isFalse);
      expect(
        const WebViewSettings(passkeysEnabled: true)
            .toMessage()
            .passkeysEnabled,
        isTrue,
      );
    });

    test('updateSettings stores the new settings', () async {
      final controller = createController();
      const settings = WebViewSettings(javaScriptEnabled: false);
      await controller.updateSettings(settings);
      expect(controller.settings, settings);
      expect(hostApi.calls.last, 'updateSettings(js: false)');
    });

    test('throw after dispose', () async {
      final controller = createController();
      await controller.dispose();
      expect(hostApi.calls.last, 'dispose(${controller.webViewId})');
      expect(controller.reload, throwsStateError);
    });
  });

  group('new windows', () {
    test('are reported only when a callback is set', () {
      expect(
        hostApi.created[createController().webViewId]!.hasNewWindowDelegate,
        isFalse,
      );

      final urls = <String>[];
      final controller = createController(onNewWindow: urls.add);
      expect(
        hostApi.created[controller.webViewId]!.hasNewWindowDelegate,
        isTrue,
      );

      dispatcher.onNewWindowRequest(controller.webViewId, 'https://a.dev/');
      expect(urls, ['https://a.dev/']);
    });
  });

  group('cookies', () {
    test('round-trip through the host API', () async {
      final controller = createController();
      final expires = DateTime.fromMillisecondsSinceEpoch(1893456000000);
      final cookie = WebViewCookie(
        name: 'sid',
        value: 'abc',
        domain: 'example.com',
        expires: expires,
        isSecure: true,
        isHttpOnly: true,
      );

      await controller.setCookie(cookie);
      expect(await controller.getCookies('https://example.com/'), [cookie]);

      await controller.clearCookies();
      expect(await controller.getCookies('https://example.com/'), isEmpty);
      expect(
        hostApi.calls,
        containsAllInOrder(['setCookie(sid)', 'clearCookies']),
      );
    });

    test('session cookies have no expiry', () async {
      final controller = createController();
      await controller.setCookie(
        const WebViewCookie(name: 'a', value: 'b', domain: 'example.com'),
      );
      expect(hostApi.cookies.values.single.expiresMillis, isNull);
      expect(hostApi.cookies.values.single.path, '/');
    });
  });

  group('user scripts', () {
    test('constructor scripts are part of the creation params', () {
      final controller = createController(
        userScripts: const [
          UserScript(
            source: 'a()',
            injectionTime: UserScriptInjectionTime.atDocumentEnd,
            mainFrameOnly: false,
          ),
        ],
      );
      final script = hostApi.created[controller.webViewId]!.userScripts.single;
      expect(script.source, 'a()');
      expect(
        script.injectionTime,
        UserScriptInjectionTimeMessage.atDocumentEnd,
      );
      expect(script.mainFrameOnly, isFalse);
    });

    test('can be added and removed', () async {
      final controller = createController();
      await controller.addUserScript(const UserScript(source: 'b()'));
      expect(hostApi.userScripts.single.source, 'b()');
      expect(
        hostApi.userScripts.single.injectionTime,
        UserScriptInjectionTimeMessage.atDocumentStart,
      );
      expect(hostApi.userScripts.single.mainFrameOnly, isTrue);

      await controller.removeAllUserScripts();
      expect(hostApi.userScripts, isEmpty);
    });
  });

  group('SSL errors', () {
    final error = SslErrorMessage(
      url: 'https://expired.test/',
      host: 'expired.test',
      message: 'expired',
    );

    test('are only delegated when a callback is set', () async {
      final without = createController();
      final withCallback = createController(
        onSslError: (_) => SslErrorDecision.cancel,
      );
      await without.ready;
      await withCallback.ready;

      expect(hostApi.created[without.webViewId]!.hasSslErrorDelegate, false);
      expect(
        hostApi.created[withCallback.webViewId]!.hasSslErrorDelegate,
        true,
      );
    });

    test('map the error and the decision', () async {
      SslError? seen;
      final controller = createController(
        onSslError: (e) {
          seen = e;
          return SslErrorDecision.proceed;
        },
      );

      expect(
        await dispatcher.onSslError(controller.webViewId, error),
        SslErrorDecisionMessage.proceed,
      );
      expect(seen!.host, 'expired.test');
      expect(seen!.url, 'https://expired.test/');
      expect(seen!.message, 'expired');
    });

    test('are cancelled without a callback or after dispose', () async {
      final without = createController();
      final disposed = createController(
        onSslError: (_) => SslErrorDecision.proceed,
      );
      await disposed.dispose();

      expect(
        await dispatcher.onSslError(without.webViewId, error),
        SslErrorDecisionMessage.cancel,
      );
      expect(
        await dispatcher.onSslError(disposed.webViewId, error),
        SslErrorDecisionMessage.cancel,
      );
    });
  });

  group('HTTP auth', () {
    final request = HttpAuthRequestMessage(host: 'a.test', realm: 'private');

    test('are only delegated when a callback is set', () async {
      final without = createController();
      final withCallback = createController(onHttpAuthRequest: (_) => null);
      await without.ready;
      await withCallback.ready;

      expect(hostApi.created[without.webViewId]!.hasHttpAuthDelegate, false);
      expect(
        hostApi.created[withCallback.webViewId]!.hasHttpAuthDelegate,
        true,
      );
    });

    test('return the credentials from the callback', () async {
      HttpAuthRequest? seen;
      final controller = createController(
        onHttpAuthRequest: (r) async {
          seen = r;
          return const HttpAuthCredentials(username: 'u', password: 'p');
        },
      );

      final result = await dispatcher.onHttpAuthRequest(
        controller.webViewId,
        request,
      );

      expect(result!.username, 'u');
      expect(result.password, 'p');
      expect(seen!.host, 'a.test');
      expect(seen!.realm, 'private');
    });

    test('cancel when the callback returns null or is missing', () async {
      final cancelling = createController(onHttpAuthRequest: (_) => null);
      final without = createController();

      expect(
        await dispatcher.onHttpAuthRequest(cancelling.webViewId, request),
        isNull,
      );
      expect(
        await dispatcher.onHttpAuthRequest(without.webViewId, request),
        isNull,
      );
    });
  });

  group('downloads', () {
    test('are only delegated when a callback is set', () async {
      final without = createController();
      final withCallback = createController(onDownloadStart: (_) {});
      await without.ready;
      await withCallback.ready;

      expect(hostApi.created[without.webViewId]!.hasDownloadDelegate, false);
      expect(
        hostApi.created[withCallback.webViewId]!.hasDownloadDelegate,
        true,
      );
    });

    test('are mapped and delivered to the matching controller', () {
      final received = <DownloadRequest>[];
      final controller = createController(onDownloadStart: received.add);
      createController(onDownloadStart: (_) => fail('wrong controller'));

      dispatcher.onDownloadStart(
        controller.webViewId,
        DownloadRequestMessage(
          url: 'https://example.com/a.pdf',
          suggestedFilename: 'a.pdf',
          mimeType: 'application/pdf',
          contentLength: 42,
        ),
      );

      expect(received.single.url, 'https://example.com/a.pdf');
      expect(received.single.suggestedFilename, 'a.pdf');
      expect(received.single.mimeType, 'application/pdf');
      expect(received.single.contentLength, 42);
    });
  });

  group('permissions', () {
    test('are only delegated when a callback is set', () async {
      final without = createController();
      final withCallback = createController(
        onPermissionRequest: (_) => PermissionDecision.grant,
      );
      await without.ready;
      await withCallback.ready;

      expect(hostApi.created[without.webViewId]!.hasPermissionDelegate, false);
      expect(
        hostApi.created[withCallback.webViewId]!.hasPermissionDelegate,
        true,
      );
    });

    test('map the request and the decision', () async {
      PermissionRequest? seen;
      final controller = createController(
        onPermissionRequest: (request) async {
          seen = request;
          return PermissionDecision.grant;
        },
      );

      final decision = await dispatcher.onPermissionRequest(
        controller.webViewId,
        PermissionRequestMessage(
          origin: 'https://example.com',
          resources: [
            PermissionResourceMessage.camera,
            PermissionResourceMessage.microphone,
          ],
        ),
      );

      expect(decision, PermissionDecisionMessage.grant);
      expect(seen!.origin, 'https://example.com');
      expect(seen!.resources, [
        PermissionResource.camera,
        PermissionResource.microphone,
      ]);
    });

    test('are denied without a callback or after dispose', () async {
      final request = PermissionRequestMessage(
        origin: 'https://example.com',
        resources: [PermissionResourceMessage.geolocation],
      );
      final without = createController();
      final disposed = createController(
        onPermissionRequest: (_) => PermissionDecision.grant,
      );
      await disposed.dispose();

      expect(
        await dispatcher.onPermissionRequest(without.webViewId, request),
        PermissionDecisionMessage.deny,
      );
      expect(
        await dispatcher.onPermissionRequest(disposed.webViewId, request),
        PermissionDecisionMessage.deny,
      );
    });
  });

  group('JavaScript handlers', () {
    test('are part of the creation params', () async {
      final controller = createController(
        javaScriptHandlers: {'sum': (_) => 0},
      );
      await controller.ready;

      expect(hostApi.created[controller.webViewId]!.javaScriptHandlerNames, [
        'sum',
      ]);
    });

    test('use advanced_webview as the default object name', () async {
      final controller = createController(javaScriptHandlers: {'a': (_) => 1});
      await controller.ready;
      expect(
        hostApi.created[controller.webViewId]!.javaScriptHandlerObjectName,
        'advanced_webview',
      );
    });

    test('accept a custom object name and reject invalid ones', () async {
      final controller = createController(
        javaScriptHandlers: {'a': (_) => 1},
        javaScriptHandlerObjectName: 'app',
      );
      await controller.ready;
      expect(
        hostApi.created[controller.webViewId]!.javaScriptHandlerObjectName,
        'app',
      );
      for (final bad in ['', '1a', 'a.b', 'a;alert(1)']) {
        expect(
          () => createController(javaScriptHandlerObjectName: bad),
          throwsArgumentError,
        );
      }
    });

    test('receive decoded arguments and return JSON', () async {
      final controller = createController(
        javaScriptHandlers: {
          'sum': (args) async => {
            'total': args.fold<num>(0, (a, b) => a + (b as num)),
          },
        },
      );

      final result = await dispatcher.onJavaScriptHandlerCall(
        controller.webViewId,
        'sum',
        '[1, 2, 3]',
      );

      expect(jsonDecode(result), {'total': 6});
    });

    test('encode a null result as JSON null', () async {
      final controller = createController(
        javaScriptHandlers: {'noop': (_) => null},
      );
      expect(
        await dispatcher.onJavaScriptHandlerCall(
          controller.webViewId,
          'noop',
          '[]',
        ),
        'null',
      );
    });

    test('reject unknown handlers and propagate errors', () async {
      final controller = createController(
        javaScriptHandlers: {'fail': (_) => throw StateError('boom')},
      );

      expect(
        dispatcher.onJavaScriptHandlerCall(controller.webViewId, 'nope', '[]'),
        throwsArgumentError,
      );
      expect(
        dispatcher.onJavaScriptHandlerCall(controller.webViewId, 'fail', '[]'),
        throwsStateError,
      );
    });

    test('are rejected after dispose', () async {
      final controller = createController(javaScriptHandlers: {'a': (_) => 1});
      await controller.dispose();
      expect(
        dispatcher.onJavaScriptHandlerCall(controller.webViewId, 'a', '[]'),
        throwsStateError,
      );
    });
  });

  group('events', () {
    test('are routed to the controller with the matching id', () {
      final finishedA = <String>[];
      final finishedB = <String>[];
      final a = createController(onPageFinished: finishedA.add);
      createController(onPageFinished: finishedB.add);

      dispatcher.onPageFinished(a.webViewId, 'https://a.dev');

      expect(finishedA, ['https://a.dev']);
      expect(finishedB, isEmpty);
    });

    test('deliver JavaScript channel messages by name', () {
      final received = <String>[];
      final controller = createController(
        javaScriptChannels: {'Bridge': received.add},
      );
      dispatcher.onJavaScriptMessage(controller.webViewId, 'Bridge', 'hi');
      dispatcher.onJavaScriptMessage(controller.webViewId, 'Unknown', 'x');
      expect(received, ['hi']);
    });

    test('map errors to WebResourceError', () {
      WebResourceError? error;
      final controller = createController(onWebResourceError: (e) => error = e);
      dispatcher.onReceivedError(
        controller.webViewId,
        WebResourceErrorMessage(
          errorCode: -2,
          message: 'host lookup',
          isMainFrame: true,
          url: 'https://x.invalid',
        ),
      );
      expect(error?.errorCode, -2);
      expect(error?.url, 'https://x.invalid');
    });

    test('ask the navigation delegate', () async {
      final controller = createController(
        onNavigationRequest: (request) async => request.url.contains('blocked')
            ? NavigationDecision.prevent
            : NavigationDecision.navigate,
      );
      Future<NavigationDecisionMessage> decide(String url) =>
          dispatcher.shouldOverrideUrlLoading(
            controller.webViewId,
            NavigationRequestMessage(url: url, isMainFrame: true),
          );

      expect(
        await decide('https://ok.dev'),
        NavigationDecisionMessage.navigate,
      );
      expect(
        await decide('https://blocked.dev'),
        NavigationDecisionMessage.prevent,
      );
    });

    test('are dropped after dispose', () async {
      final finished = <String>[];
      final controller = createController(onPageFinished: finished.add);
      await controller.dispose();
      dispatcher.onPageFinished(controller.webViewId, 'https://a.dev');
      expect(finished, isEmpty);
    });
  });
}
