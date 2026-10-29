// Runs on a real device or simulator: `flutter test integration_test`.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_mobile_webview/flutter_mobile_webview.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads HTML, evaluates JS and receives channel messages', (
    tester,
  ) async {
    final finished = Completer<void>();
    final messages = <String>[];
    final controller = MobileWebViewController(
      javaScriptChannels: {'Echo': messages.add},
      onPageFinished: (_) {
        if (!finished.isCompleted) finished.complete();
      },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: MobileWebView(controller: controller)),
    );
    await controller.loadHtmlString(
      '<html><head><title>hello</title></head><body></body></html>',
    );
    await finished.future.timeout(const Duration(seconds: 10));

    expect(await controller.title(), 'hello');
    expect(await controller.runJavaScriptReturningResult('1 + 2'), 3);
    expect(await controller.runJavaScriptReturningResult('({a: [1, "b"]})'), {
      'a': [1, 'b'],
    });
    expect(await controller.runJavaScriptReturningResult('undefined'), isNull);

    await controller.runJavaScript('Echo.postMessage("hi")');
    await tester.pumpAndSettle();
    expect(messages, ['hi']);
  });
}
