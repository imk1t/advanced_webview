import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';

/// Displays the native WebView owned by [controller].
///
/// Disposing this widget does not destroy the WebView; call
/// [MobileWebViewController.dispose] when it is no longer needed.
class MobileWebView extends StatelessWidget {
  const MobileWebView({
    super.key,
    required this.controller,
    this.gestureRecognizers = const {},
  });

  /// Must match `VIEW_TYPE` / `viewType` in the native plugins.
  static const String viewType = 'dev.k1t.flutter_mobile_webview/webview';

  final MobileWebViewController controller;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: controller.ready,
      builder: (context, snapshot) {
        // The native factory looks the WebView up by id, so it must exist
        // before the platform view is requested.
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.expand();
        }
        if (snapshot.hasError) {
          return ErrorWidget(snapshot.error!);
        }
        return _buildPlatformView();
      },
    );
  }

  Widget _buildPlatformView() {
    final creationParams = <String, Object?>{'webViewId': controller.webViewId};
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidView(
          viewType: viewType,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          gestureRecognizers: gestureRecognizers,
        );
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: viewType,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          gestureRecognizers: gestureRecognizers,
        );
      default:
        return ErrorWidget(
          UnsupportedError(
            'flutter_mobile_webview supports only Android and iOS',
          ),
        );
    }
  }
}
