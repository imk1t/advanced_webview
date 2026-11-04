import 'dart:ui' show Color, VoidCallback;

import 'package:flutter/foundation.dart';

import 'controller.dart';
import 'navigation.dart';
import 'platform/event_dispatcher.dart';
import 'platform/messages.g.dart';
import 'settings.dart';

/// How the toolbar of an [AdvancedInAppBrowser] looks and what it offers.
@immutable
class InAppBrowserOptions {
  const InAppBrowserOptions({
    this.toolbarColor,
    this.toolbarTitle,
    this.showUrl = false,
    this.showNavigationButtons = true,
    this.closeButtonLabel,
    this.settings = const WebViewSettings(),
  });

  /// Background of the toolbar. `null` uses the platform default.
  ///
  /// Android: the background of the toolbar of the browser activity. iOS:
  /// `UINavigationBarAppearance.backgroundColor`. The title and buttons keep
  /// the platform's colours, so pick a colour they stay readable on.
  final Color? toolbarColor;

  /// Fixed toolbar title. `null` shows the title of the current page.
  final String? toolbarTitle;

  /// Shows the current URL under the title.
  final bool showUrl;

  /// Shows back, forward and reload buttons.
  final bool showNavigationButtons;

  /// Label of the button that closes the browser. `null` uses the platform's
  /// localized "Close" / "Done".
  final String? closeButtonLabel;

  /// Settings of the WebView inside the browser, including the `android:` and
  /// `ios:` platform settings.
  final WebViewSettings settings;
}

/// A full-screen in-app browser: a native screen with a toolbar and a WebView,
/// presented over the Flutter UI.
///
/// ```dart
/// final browser = AdvancedInAppBrowser(onClosed: () => print('closed'));
/// await browser.open(Uri.parse('https://example.com'));
/// ```
///
/// One instance shows at most one browser at a time; after it closes, [open]
/// can be called again. The browser creates its own WebView, so cookies and
/// settings of other [AdvancedWebViewController]s are unaffected (on iOS, set
/// [IOSWebViewSettings.incognito] to also isolate the website data).
///
/// Android: a dedicated `Activity` with an `android.widget.Toolbar` hosting
/// the `WebView`. iOS: a `UIViewController` with a `WKWebView`, presented
/// modally full screen in a `UINavigationController`. The Android back button
/// and the iOS swipe-back gesture are not bound to the page history: the back
/// button goes back in the page first and closes the browser when there is
/// nothing to go back to.
class AdvancedInAppBrowser {
  AdvancedInAppBrowser({
    this.onOpened,
    this.onClosed,
    this.onPageStarted,
    this.onPageFinished,
    this.onLoadError,
    @visibleForTesting AdvancedWebViewHostApi? hostApi,
    @visibleForTesting WebViewEventDispatcher? dispatcher,
    // ignore: prefer_initializing_formals
  }) : _hostApi = hostApi,
       // ignore: prefer_initializing_formals
       _dispatcher = dispatcher;

  /// Called once the browser is on screen.
  final VoidCallback? onOpened;

  /// Called after the browser was dismissed, by the user or by [close].
  final VoidCallback? onClosed;

  /// Called when the browser starts loading a page.
  final PageEventCallback? onPageStarted;

  /// Called when the browser finished loading a page.
  final PageEventCallback? onPageFinished;

  /// Called when the main page fails to load. Errors of sub-resources
  /// (images, scripts) are not reported.
  final WebResourceErrorCallback? onLoadError;

  final AdvancedWebViewHostApi? _hostApi;
  final WebViewEventDispatcher? _dispatcher;
  AdvancedWebViewController? _controller;
  bool _isOpened = false;

  /// Whether the browser is on screen.
  bool get isOpened => _isOpened;

  /// Shows the browser and starts loading [url].
  ///
  /// Throws a [StateError] when the browser is already open, and a
  /// `PlatformException` when there is no screen to present from.
  Future<void> open(
    Uri url, {
    InAppBrowserOptions options = const InAppBrowserOptions(),
  }) async {
    if (_controller != null) {
      throw StateError('The in-app browser is already open');
    }
    final controller = AdvancedWebViewController(
      settings: options.settings,
      onPageStarted: onPageStarted,
      onPageFinished: onPageFinished,
      onWebResourceError: (error) {
        if (error.isMainFrame) onLoadError?.call(error);
      },
      // ignore: invalid_use_of_visible_for_testing_member
      hostApi: _hostApi,
      // ignore: invalid_use_of_visible_for_testing_member
      dispatcher: _dispatcher,
    );
    _controller = controller;
    controller.onInAppBrowserClosed = () => _handleClosed(controller);
    try {
      await controller.ready;
      await controller.openInAppBrowser(
        InAppBrowserParamsMessage(
          webViewId: controller.webViewId,
          showUrl: options.showUrl,
          showNavigationButtons: options.showNavigationButtons,
          toolbarColor: options.toolbarColor?.toARGB32(),
          toolbarTitle: options.toolbarTitle,
          closeButtonLabel: options.closeButtonLabel,
        ),
      );
    } catch (_) {
      _controller = null;
      await controller.dispose();
      rethrow;
    }
    if (_controller != controller) return; // dismissed while opening
    _isOpened = true;
    onOpened?.call();
    await controller.loadUrl(url.toString());
  }

  /// Dismisses the browser; does nothing when it is not open.
  Future<void> close() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.closeInAppBrowser();
    await _handleClosed(controller);
  }

  /// Loads [url] in the open browser.
  Future<void> loadUrl(Uri url, {Map<String, String> headers = const {}}) =>
      _open.loadUrl(url.toString(), headers: headers);

  /// Runs [source] in the open browser's page and returns the JSON-decoded
  /// result (`undefined` becomes `null`).
  Future<Object?> evaluateJavaScript(String source) =>
      _open.runJavaScriptReturningResult(source);

  AdvancedWebViewController get _open {
    final controller = _controller;
    if (controller == null || !_isOpened) {
      throw StateError('The in-app browser is not open');
    }
    return controller;
  }

  Future<void> _handleClosed(AdvancedWebViewController controller) async {
    if (_controller != controller) return;
    final wasOpened = _isOpened;
    _controller = null;
    _isOpened = false;
    await controller.dispose();
    if (wasOpened) onClosed?.call();
  }
}
