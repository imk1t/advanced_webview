import 'dart:convert';
import 'dart:typed_data';

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
    ScrollChangedCallback? onScrollChanged,
    LongPressCallback? onLongPress,
    ConsoleMessageCallback? onConsoleMessage,
    WebResourceErrorCallback? onWebResourceError,
    HttpErrorCallback? onHttpError,
    NavigationRequestCallback? onNavigationRequest,
    NewWindowCallback? onNewWindow,
    PermissionRequestCallback? onPermissionRequest,
    JsDialogCallback? onJsDialog,
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
      onScrollChanged: onScrollChanged,
      onLongPress: onLongPress,
      onConsoleMessage: onConsoleMessage,
      onWebResourceError: onWebResourceError,
      onHttpError: onHttpError,
      onNavigationRequest: onNavigationRequest,
      onNewWindow: onNewWindow,
      onPermissionRequest: onPermissionRequest,
      onJsDialog: onJsDialog,
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

  group('loading', () {
    test('loadRequest, loadFlutterAsset and loadFile forward', () async {
      final controller = createController();
      await controller.loadRequest(
        'https://a.dev/form',
        method: WebViewHttpMethod.post,
        body: Uint8List.fromList([1, 2, 3]),
      );
      await controller.loadRequest('https://a.dev', headers: {'X': '1'});
      await controller.loadFlutterAsset('assets/a.html');
      await controller.loadFile('/tmp/a.html');

      expect(hostApi.calls.skip(1), [
        'loadRequest(HttpMethodMessage.post https://a.dev/form, {}, 3)',
        'loadRequest(HttpMethodMessage.get https://a.dev, {X: 1}, null)',
        'loadFlutterAsset(assets/a.html)',
        'loadFile(/tmp/a.html)',
      ]);
    });

    test('a body needs POST', () {
      final controller = createController();

      expect(
        () => controller.loadRequest(
          'https://a.dev',
          body: Uint8List.fromList([1]),
        ),
        throwsArgumentError,
      );
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
        ios: IOSWebViewSettings(allowsBackForwardNavigationGestures: true),
      ).toMessage();
      expect(message.inspectable, isTrue);
      expect(message.allowsBackForwardNavigationGestures, isTrue);
    });

    test('window and scroll settings are passed to native', () {
      final defaults = const WebViewSettings().toMessage();
      expect(defaults.javaScriptCanOpenWindowsAutomatically, isTrue);
      expect(defaults.scrollbarsVisible, isTrue);
      expect(defaults.overScrollEnabled, isTrue);
      final message = const WebViewSettings(
        javaScriptCanOpenWindowsAutomatically: false,
        scrollbarsVisible: false,
        overScrollEnabled: false,
      ).toMessage();
      expect(message.javaScriptCanOpenWindowsAutomatically, isFalse);
      expect(message.scrollbarsVisible, isFalse);
      expect(message.overScrollEnabled, isFalse);
    });

    test('applicationNameForUserAgent is passed to native', () {
      expect(
        const WebViewSettings().toMessage().applicationNameForUserAgent,
        isNull,
      );
      expect(
        const WebViewSettings(
          ios: IOSWebViewSettings(applicationNameForUserAgent: 'MyApp/1.0'),
        ).toMessage().applicationNameForUserAgent,
        'MyApp/1.0',
      );
    });

    test('contentMode is passed to native', () {
      expect(
        const WebViewSettings().toMessage().contentMode,
        ContentModeMessage.recommended,
      );
      expect(
        const WebViewSettings(
          ios: IOSWebViewSettings(contentMode: WebViewContentMode.desktop),
        ).toMessage().contentMode,
        ContentModeMessage.desktop,
      );
    });

    test('allowsLinkPreview is passed to native', () {
      expect(const WebViewSettings().toMessage().allowsLinkPreview, isTrue);
      expect(
        const WebViewSettings(ios: IOSWebViewSettings(allowsLinkPreview: false))
            .toMessage()
            .allowsLinkPreview,
        isFalse,
      );
    });

    test('geolocationEnabled is passed to native', () {
      expect(const WebViewSettings().toMessage().geolocationEnabled, isTrue);
      expect(
        const WebViewSettings(
          android: AndroidWebViewSettings(geolocationEnabled: false),
        ).toMessage().geolocationEnabled,
        isFalse,
      );
    });

    test('incognito is passed to native', () {
      expect(const WebViewSettings().toMessage().incognito, isFalse);
      expect(
        const WebViewSettings(ios: IOSWebViewSettings(incognito: true))
            .toMessage()
            .incognito,
        isTrue,
      );
    });

    test('pullToRefreshEnabled is passed to native', () {
      expect(const WebViewSettings().toMessage().pullToRefreshEnabled, isFalse);
      expect(
        const WebViewSettings(pullToRefreshEnabled: true)
            .toMessage()
            .pullToRefreshEnabled,
        isTrue,
      );
    });

    test('Android security settings default to the safe values', () {
      final defaults = const WebViewSettings().toMessage();
      expect(defaults.domStorageEnabled, isTrue);
      expect(defaults.allowFileAccess, isFalse);
      expect(defaults.allowContentAccess, isFalse);
      expect(defaults.mixedContentMode, MixedContentModeMessage.neverAllow);
      final message = const WebViewSettings(
        android: AndroidWebViewSettings(
          domStorageEnabled: false,
          allowFileAccess: true,
          allowContentAccess: true,
          mixedContentMode: WebViewMixedContentMode.compatibility,
        ),
      ).toMessage();
      expect(message.domStorageEnabled, isFalse);
      expect(message.allowFileAccess, isTrue);
      expect(message.allowContentAccess, isTrue);
      expect(message.mixedContentMode, MixedContentModeMessage.compatibility);
    });

    test('cacheMode is passed to native', () {
      expect(
        const WebViewSettings().toMessage().cacheMode,
        CacheModeMessage.normal,
      );
      expect(
        const WebViewSettings(cacheMode: WebViewCacheMode.noCache)
            .toMessage()
            .cacheMode,
        CacheModeMessage.noCache,
      );
    });

    test('textZoom and minimumFontSize are passed to native', () {
      final defaults = const WebViewSettings().toMessage();
      expect(defaults.textZoom, 100);
      expect(defaults.minimumFontSize, isNull);
      final message = const WebViewSettings(
        textZoom: 150,
        minimumFontSize: 12,
      ).toMessage();
      expect(message.textZoom, 150);
      expect(message.minimumFontSize, 12);
      expect(
        () => WebViewSettings(textZoom: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test(
      'findText maps the native result and clearMatches is forwarded',
      () async {
        final controller = createController();
        hostApi.nextFindResult = FindResultMessage(
          found: true,
          matchCount: 3,
          activeMatchIndex: 1,
        );
        final result = await controller.findText('abc', forward: false);
        expect(
          result,
          const FindResult(found: true, matchCount: 3, activeMatchIndex: 1),
        );
        expect(hostApi.calls, contains('findText(abc, false)'));

        hostApi.nextFindResult = FindResultMessage(found: false);
        expect(
          await controller.findText('zzz'),
          const FindResult(found: false),
        );
        await controller.clearMatches();
        expect(hostApi.calls, contains('clearMatches'));
      },
    );

    test('takeScreenshot returns the PNG bytes from native', () async {
      final controller = createController();
      final bytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
      hostApi.nextScreenshot = bytes;
      expect(await controller.takeScreenshot(), bytes);
      expect(hostApi.calls, contains('takeScreenshot'));
      hostApi.nextScreenshot = null;
      expect(await controller.takeScreenshot(), isNull);
    });

    test('passkeysEnabled is passed to the native settings', () {
      expect(const WebViewSettings().toMessage().passkeysEnabled, isFalse);
      expect(
        const WebViewSettings(
          android: AndroidWebViewSettings(passkeysEnabled: true),
        ).toMessage().passkeysEnabled,
        isTrue,
      );
    });

    test('platform settings default, compare and copy', () {
      expect(const WebViewSettings(), const WebViewSettings());
      const custom = WebViewSettings(
        android: AndroidWebViewSettings(supportZoom: false),
        ios: IOSWebViewSettings(allowsInlineMediaPlayback: true),
      );
      expect(custom, isNot(const WebViewSettings()));
      expect(custom.hashCode, isNot(const WebViewSettings().hashCode));
      final message = custom.toMessage();
      expect(message.supportZoom, isFalse);
      expect(message.allowsInlineMediaPlayback, isTrue);
      final copy = custom.copyWith(
        android: custom.android.copyWith(supportZoom: true),
      );
      expect(copy.android.supportZoom, isTrue);
      expect(copy.ios, custom.ios);
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

  group('printing', () {
    test('printPage forwards the job name', () async {
      final controller = createController();
      await controller.printPage();
      await controller.printPage(jobName: 'Invoice');
      expect(
        hostApi.calls,
        containsAllInOrder(['printPage(null)', 'printPage(Invoice)']),
      );
    });
  });

  group('state', () {
    test('saveState and restoreState use the host API', () async {
      final controller = createController();
      expect(await controller.saveState(), isNull);
      hostApi.nextState = Uint8List.fromList([1, 2, 3]);
      expect(await controller.saveState(), [1, 2, 3]);
      expect(await controller.restoreState(Uint8List(2)), isTrue);
      hostApi.nextRestoreResult = false;
      expect(await controller.restoreState(Uint8List(2)), isFalse);
      expect(hostApi.calls, contains('restoreState(2)'));
    });
  });

  group('console messages', () {
    test('are flagged at creation and routed to the callback', () {
      final without = createController();
      expect(
        hostApi.created[without.webViewId]!.hasConsoleMessageDelegate,
        isFalse,
      );

      final messages = <WebViewConsoleMessage>[];
      final controller = createController(onConsoleMessage: messages.add);
      expect(
        hostApi.created[controller.webViewId]!.hasConsoleMessageDelegate,
        isTrue,
      );
      dispatcher.onConsoleMessage(
        controller.webViewId,
        ConsoleMessageMessage(
          level: ConsoleMessageLevelMessage.warning,
          message: 'careful',
          sourceUrl: 'https://a.dev/app.js',
          lineNumber: 7,
        ),
      );
      dispatcher.onConsoleMessage(
        controller.webViewId,
        ConsoleMessageMessage(
          level: ConsoleMessageLevelMessage.debug,
          message: 'details',
        ),
      );
      expect(messages, const [
        WebViewConsoleMessage(
          level: WebViewConsoleMessageLevel.warning,
          message: 'careful',
          sourceUrl: 'https://a.dev/app.js',
          lineNumber: 7,
        ),
        WebViewConsoleMessage(
          level: WebViewConsoleMessageLevel.debug,
          message: 'details',
        ),
      ]);
    });

    test('every level maps to the matching public level', () {
      for (final level in ConsoleMessageLevelMessage.values) {
        expect(WebViewConsoleMessageLevel.values[level.index].name, level.name);
      }
    });

    test('are dropped after dispose', () async {
      final messages = <WebViewConsoleMessage>[];
      final controller = createController(onConsoleMessage: messages.add);
      await controller.dispose();
      dispatcher.onConsoleMessage(
        controller.webViewId,
        ConsoleMessageMessage(
          level: ConsoleMessageLevelMessage.log,
          message: 'late',
        ),
      );
      expect(messages, isEmpty);
    });
  });

  group('hit testing', () {
    test('onLongPress is routed and flagged at creation', () {
      final without = createController();
      expect(hostApi.created[without.webViewId]!.hasLongPressDelegate, isFalse);

      final offsets = <Offset>[];
      final controller = createController(onLongPress: offsets.add);
      expect(hostApi.created[controller.webViewId]!.hasLongPressDelegate, true);
      dispatcher.onLongPress(controller.webViewId, 3, 4);
      expect(offsets, [const Offset(3, 4)]);
    });

    test('hitTest maps the script result to a type', () async {
      final controller = createController();
      hostApi.nextJavaScriptResult =
          '{"link":"https://a.dev/","image":"https://a.dev/i.png"}';
      final both = await controller.hitTest(const Offset(1, 2));
      expect(both.type, WebViewHitTestType.imageLink);
      expect(both.linkUrl, 'https://a.dev/');
      expect(both.imageUrl, 'https://a.dev/i.png');
      expect(hostApi.calls.last, contains('elementFromPoint(x, y)'));
      expect(hostApi.calls.last, contains('})(1.0, 2.0)'));

      hostApi.nextJavaScriptResult = '{"link":"https://a.dev/","image":null}';
      expect(
        (await controller.hitTest(Offset.zero)).type,
        WebViewHitTestType.link,
      );
      hostApi.nextJavaScriptResult = '{"link":null,"image":"https://a.dev/i"}';
      expect(
        (await controller.hitTest(Offset.zero)).type,
        WebViewHitTestType.image,
      );
      hostApi.nextJavaScriptResult = '{"link":null,"image":null}';
      expect(
        (await controller.hitTest(Offset.zero)).type,
        WebViewHitTestType.none,
      );
      hostApi.nextJavaScriptResult = null;
      expect(
        (await controller.hitTest(Offset.zero)).type,
        WebViewHitTestType.none,
      );
    });
  });

  group('scrolling', () {
    test('scrollTo, scrollBy and scrollPosition use the host API', () async {
      final controller = createController();
      await controller.scrollTo(1, 2);
      await controller.scrollBy(3, 4);
      hostApi.nextScrollPosition = ScrollPositionMessage(x: 5, y: 6);
      expect(await controller.scrollPosition(), const Offset(5, 6));
      expect(
        hostApi.calls,
        containsAllInOrder(['scrollTo(1.0, 2.0)', 'scrollBy(3.0, 4.0)']),
      );
    });

    test('onScrollChanged is routed and flagged at creation', () {
      final without = createController();
      expect(hostApi.created[without.webViewId]!.hasScrollDelegate, isFalse);

      final offsets = <Offset>[];
      final controller = createController(onScrollChanged: offsets.add);
      expect(hostApi.created[controller.webViewId]!.hasScrollDelegate, isTrue);
      dispatcher.onScrollChanged(controller.webViewId, 1.5, 20);
      expect(offsets, [const Offset(1.5, 20)]);
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

    test('clears website data, everything by default', () async {
      final controller = createController();

      await controller.clearWebsiteData();
      await controller.clearWebsiteData(types: {WebsiteDataType.indexedDb});
      await controller.clearWebsiteData(types: {});

      expect(hostApi.clearedWebsiteData, [
        WebsiteDataTypeMessage.values,
        [WebsiteDataTypeMessage.indexedDb],
        isEmpty,
      ]);
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

  group('HTTP errors', () {
    test('are only delegated when a callback is set', () async {
      final without = createController();
      final withCallback = createController(onHttpError: (_) {});
      await without.ready;
      await withCallback.ready;

      expect(hostApi.created[without.webViewId]!.hasHttpErrorDelegate, false);
      expect(
        hostApi.created[withCallback.webViewId]!.hasHttpErrorDelegate,
        true,
      );
    });

    test('are mapped and routed by webViewId', () async {
      HttpError? error;
      final controller = createController(onHttpError: (e) => error = e);
      final other = createController(onHttpError: (_) => fail('wrong view'));
      addTearDown(other.dispose);

      dispatcher.onReceivedHttpError(
        controller.webViewId,
        HttpErrorMessage(
          url: 'https://example.com/missing',
          statusCode: 404,
          isMainFrame: true,
        ),
      );

      expect(error?.statusCode, 404);
      expect(error?.url, 'https://example.com/missing');
      expect(error?.isMainFrame, true);
    });
  });

  group('JavaScript dialogs', () {
    JsDialogRequestMessage prompt() => JsDialogRequestMessage(
      type: JsDialogTypeMessage.prompt,
      message: 'Name?',
      url: 'https://example.com/',
      defaultText: 'Ann',
    );

    test('are only delegated when a callback is set', () async {
      final without = createController();
      final withCallback = createController(
        onJsDialog: (_) => const JsDialogResponse.dismiss(),
      );
      await without.ready;
      await withCallback.ready;

      expect(hostApi.created[without.webViewId]!.hasJsDialogDelegate, false);
      expect(
        hostApi.created[withCallback.webViewId]!.hasJsDialogDelegate,
        true,
      );
    });

    test('map the request and an accepted answer', () async {
      JsDialogRequest? seen;
      final controller = createController(
        onJsDialog: (request) async {
          seen = request;
          return const JsDialogResponse.accept(text: 'Bob');
        },
      );

      final result = await dispatcher.onJsDialog(
        controller.webViewId,
        prompt(),
      );

      expect(result.accepted, true);
      expect(result.text, 'Bob');
      expect(seen!.type, JsDialogType.prompt);
      expect(seen!.message, 'Name?');
      expect(seen!.url, 'https://example.com/');
      expect(seen!.defaultText, 'Ann');
    });

    test('a dismissal carries no text', () async {
      final controller = createController(
        onJsDialog: (_) => const JsDialogResponse.dismiss(),
      );

      final result = await dispatcher.onJsDialog(
        controller.webViewId,
        prompt(),
      );

      expect(result.accepted, false);
      expect(result.text, isNull);
    });

    test('are dismissed after dispose', () async {
      final controller = createController(
        onJsDialog: (_) => const JsDialogResponse.accept(),
      );
      await controller.dispose();

      final result = await dispatcher.onJsDialog(
        controller.webViewId,
        prompt(),
      );

      expect(result.accepted, false);
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
