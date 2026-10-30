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

  MobileWebViewController createController({
    Map<String, JavaScriptMessageCallback> javaScriptChannels = const {},
    PageEventCallback? onPageFinished,
    WebResourceErrorCallback? onWebResourceError,
    NavigationRequestCallback? onNavigationRequest,
  }) {
    return MobileWebViewController(
      hostApi: hostApi,
      dispatcher: dispatcher,
      javaScriptChannels: javaScriptChannels,
      onPageFinished: onPageFinished,
      onWebResourceError: onWebResourceError,
      onNavigationRequest: onNavigationRequest,
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
