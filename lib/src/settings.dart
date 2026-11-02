import 'package:flutter/foundation.dart';

import 'platform/messages.g.dart';

/// How the WebView uses its HTTP cache.
enum WebViewCacheMode {
  /// Follows HTTP cache headers (the platform default).
  normal,

  /// Uses cached content even if it is stale, and loads from the network only
  /// when nothing is cached.
  preferCache,

  /// Never touches the network; pages that are not cached fail to load.
  cacheOnly,

  /// Ignores the cache and always loads from the network.
  noCache,
}

/// Per-WebView settings.
///
/// Settings marked "creation only" are applied when the native view is created
/// and ignored by [AdvancedWebViewController.updateSettings] on that platform.
@immutable
class WebViewSettings {
  const WebViewSettings({
    this.javaScriptEnabled = true,
    this.mediaPlaybackRequiresUserGesture = true,
    this.allowsInlineMediaPlayback = false,
    this.supportZoom = true,
    this.transparentBackground = false,
    this.passkeysEnabled = false,
    this.allowsBackForwardNavigationGestures = false,
    this.inspectable = false,
    this.textZoom = 100,
    this.cacheMode = WebViewCacheMode.normal,
    this.minimumFontSize,
    this.userAgent,
  }) : assert(textZoom > 0, 'textZoom must be positive'),
       assert(
         minimumFontSize == null || minimumFontSize >= 0,
         'minimumFontSize must not be negative',
       );

  final bool javaScriptEnabled;

  /// Creation only on iOS.
  final bool mediaPlaybackRequiresUserGesture;

  /// iOS only, creation only.
  final bool allowsInlineMediaPlayback;

  /// Android only.
  final bool supportZoom;

  final bool transparentBackground;

  /// Enables WebAuthn / passkeys for web content loaded in the WebView.
  ///
  /// Android only: turns on `WebSettingsCompat.setWebAuthenticationSupport`
  /// (a no-op when the installed WebView does not support it). On iOS the
  /// setting is ignored; WKWebView supports passkeys whenever the app has the
  /// Associated Domains `webcredentials:` entitlement for the site's domain.
  /// Either way, the site's domain must be associated with the app (Digital
  /// Asset Links on Android, `apple-app-site-association` on iOS).
  final bool passkeysEnabled;

  /// Lets the user swipe from the screen edge to go back and forward.
  ///
  /// iOS only (`allowsBackForwardNavigationGestures`). Android has no
  /// equivalent in the WebView, so the setting is ignored there.
  final bool allowsBackForwardNavigationGestures;

  /// Allows the page to be inspected with Safari Web Inspector (iOS) or
  /// `chrome://inspect` (Android).
  ///
  /// On Android this is process-wide: it calls
  /// `WebView.setWebContentsDebuggingEnabled`, which applies to every WebView
  /// in the app, so the latest value set by any controller wins.
  final bool inspectable;

  /// Text size as a percentage; 100 is the page's own size. Must be positive.
  ///
  /// Android scales text only (`WebSettings.setTextZoom`). iOS has no text-only
  /// zoom, so the whole page is scaled (`WKWebView.pageZoom`).
  final int textZoom;

  /// How loads use the HTTP cache.
  ///
  /// Android applies it to every load of the WebView
  /// (`WebSettings.setCacheMode`). iOS applies it as the cache policy of
  /// requests started by `loadUrl`; links the user follows and subresources
  /// use the default policy.
  final WebViewCacheMode cacheMode;

  /// Smallest font size the WebView renders: sp on Android
  /// (`WebSettings.setMinimumFontSize`), pt on iOS
  /// (`WKPreferences.minimumFontSize`). `null` uses the platform default.
  final int? minimumFontSize;

  /// `null` uses the platform default user agent.
  final String? userAgent;

  WebViewSettings copyWith({
    bool? javaScriptEnabled,
    bool? mediaPlaybackRequiresUserGesture,
    bool? allowsInlineMediaPlayback,
    bool? supportZoom,
    bool? transparentBackground,
    bool? passkeysEnabled,
    bool? allowsBackForwardNavigationGestures,
    bool? inspectable,
    int? textZoom,
    WebViewCacheMode? cacheMode,
    ValueGetter<int?>? minimumFontSize,
    ValueGetter<String?>? userAgent,
  }) {
    return WebViewSettings(
      javaScriptEnabled: javaScriptEnabled ?? this.javaScriptEnabled,
      mediaPlaybackRequiresUserGesture:
          mediaPlaybackRequiresUserGesture ??
          this.mediaPlaybackRequiresUserGesture,
      allowsInlineMediaPlayback:
          allowsInlineMediaPlayback ?? this.allowsInlineMediaPlayback,
      supportZoom: supportZoom ?? this.supportZoom,
      transparentBackground:
          transparentBackground ?? this.transparentBackground,
      passkeysEnabled: passkeysEnabled ?? this.passkeysEnabled,
      allowsBackForwardNavigationGestures:
          allowsBackForwardNavigationGestures ??
          this.allowsBackForwardNavigationGestures,
      inspectable: inspectable ?? this.inspectable,
      textZoom: textZoom ?? this.textZoom,
      cacheMode: cacheMode ?? this.cacheMode,
      minimumFontSize: minimumFontSize != null
          ? minimumFontSize()
          : this.minimumFontSize,
      userAgent: userAgent != null ? userAgent() : this.userAgent,
    );
  }

  WebViewSettingsMessage toMessage() => WebViewSettingsMessage(
    javaScriptEnabled: javaScriptEnabled,
    mediaPlaybackRequiresUserGesture: mediaPlaybackRequiresUserGesture,
    allowsInlineMediaPlayback: allowsInlineMediaPlayback,
    supportZoom: supportZoom,
    transparentBackground: transparentBackground,
    passkeysEnabled: passkeysEnabled,
    allowsBackForwardNavigationGestures: allowsBackForwardNavigationGestures,
    inspectable: inspectable,
    textZoom: textZoom,
    cacheMode: CacheModeMessage.values[cacheMode.index],
    minimumFontSize: minimumFontSize,
    userAgent: userAgent,
  );

  @override
  bool operator ==(Object other) =>
      other is WebViewSettings &&
      other.javaScriptEnabled == javaScriptEnabled &&
      other.mediaPlaybackRequiresUserGesture ==
          mediaPlaybackRequiresUserGesture &&
      other.allowsInlineMediaPlayback == allowsInlineMediaPlayback &&
      other.supportZoom == supportZoom &&
      other.transparentBackground == transparentBackground &&
      other.passkeysEnabled == passkeysEnabled &&
      other.allowsBackForwardNavigationGestures ==
          allowsBackForwardNavigationGestures &&
      other.inspectable == inspectable &&
      other.textZoom == textZoom &&
      other.cacheMode == cacheMode &&
      other.minimumFontSize == minimumFontSize &&
      other.userAgent == userAgent;

  @override
  int get hashCode => Object.hash(
    javaScriptEnabled,
    mediaPlaybackRequiresUserGesture,
    allowsInlineMediaPlayback,
    supportZoom,
    transparentBackground,
    passkeysEnabled,
    allowsBackForwardNavigationGestures,
    inspectable,
    textZoom,
    cacheMode,
    minimumFontSize,
    userAgent,
  );
}
