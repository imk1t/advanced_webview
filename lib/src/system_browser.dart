import 'dart:ui' show Color, VoidCallback;

import 'package:flutter/foundation.dart';

import 'platform/event_dispatcher.dart';
import 'platform/messages.g.dart';

/// How a page opened with [AdvancedSystemBrowser] looks.
@immutable
class SystemBrowserOptions {
  const SystemBrowserOptions({this.toolbarColor});

  /// Background of the browser's toolbar. `null` uses the platform default.
  ///
  /// Android: `CustomTabColorSchemeParams.toolbarColor`. iOS:
  /// `SFSafariViewController.preferredBarTintColor`.
  final Color? toolbarColor;
}

/// Opens a page in the system's own browser UI, shown over the app: Chrome
/// Custom Tabs on Android and `SFSafariViewController` on iOS.
///
/// Unlike [AdvancedInAppBrowser] it is not a WebView of this plugin. The page
/// runs in the user's browser, with its cookies, saved passwords and
/// passkeys, and the app cannot read or script it. That makes it the right
/// place for OAuth sign-in and anything else that should not run inside an
/// embedded WebView.
///
/// ```dart
/// final browser = AdvancedSystemBrowser(onClosed: () => print('closed'));
/// if (await browser.isAvailable()) {
///   await browser.open(Uri.parse('https://example.com/login'));
/// }
/// ```
///
/// Only `http` and `https` URLs are accepted.
class AdvancedSystemBrowser {
  AdvancedSystemBrowser({
    this.onClosed,
    @visibleForTesting AdvancedWebViewHostApi? hostApi,
    @visibleForTesting WebViewEventDispatcher? dispatcher,
  }) : _hostApi = hostApi ?? AdvancedWebViewHostApi(),
       _dispatcher = dispatcher ?? WebViewEventDispatcher.instance;

  /// Called after the browser was dismissed.
  ///
  /// iOS reports the dismissal reliably
  /// (`SFSafariViewControllerDelegate.safariViewControllerDidFinish`). Android
  /// has no such event for Custom Tabs, so it is best effort: it is called
  /// when the app comes back to the foreground after the tab was shown, which
  /// also happens when the user returns by another route or switches apps.
  final VoidCallback? onClosed;

  final AdvancedWebViewHostApi _hostApi;
  final WebViewEventDispatcher _dispatcher;
  static int _nextSessionId = 0;

  /// Whether a system browser can be opened.
  ///
  /// Always `true` on iOS. On Android it is `true` when an app can handle
  /// `https` links.
  ///
  /// Android: `Intent.resolveActivity` for an `https` view intent.
  /// iOS: always `true`.
  Future<bool> isAvailable() => _hostApi.isSystemBrowserAvailable();

  /// Opens [url] in the system browser.
  ///
  /// Throws an [ArgumentError] unless [url] is an absolute `http` or `https`
  /// URL, and a `PlatformException` when there is no screen to present from
  /// (`not-attached`) or no browser can handle it (`unavailable`).
  ///
  /// Android: `CustomTabsIntent.launchUrl` (AndroidX Browser).
  /// iOS: `SFSafariViewController`, presented modally.
  Future<void> open(
    Uri url, {
    SystemBrowserOptions options = const SystemBrowserOptions(),
  }) async {
    if (!url.isAbsolute || (url.scheme != 'http' && url.scheme != 'https')) {
      throw ArgumentError.value(url, 'url', 'must be an http or https URL');
    }
    final sessionId = _nextSessionId++;
    _dispatcher.registerSystemBrowser(sessionId, () => onClosed?.call());
    try {
      await _hostApi.openSystemBrowser(
        SystemBrowserParamsMessage(
          sessionId: sessionId,
          url: url.toString(),
          toolbarColor: options.toolbarColor?.toARGB32(),
        ),
      );
    } catch (_) {
      _dispatcher.unregisterSystemBrowser(sessionId);
      rethrow;
    }
  }
}
