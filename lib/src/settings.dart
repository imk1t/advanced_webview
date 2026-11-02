import 'package:flutter/foundation.dart';

import 'platform/messages.g.dart';

/// How the WebView treats HTTP content on an HTTPS page (Android only).
enum WebViewMixedContentMode {
  /// Blocks all insecure content on secure pages (the safe choice).
  neverAllow,

  /// Loads insecure images and the like, but blocks scripts and frames, as
  /// recent browsers do.
  compatibility,

  /// Loads everything. This lets an attacker on the network tamper with a
  /// secure page, so avoid it outside of tests.
  alwaysAllow,
}

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
    this.incognito = false,
    this.javaScriptCanOpenWindowsAutomatically = true,
    this.scrollbarsVisible = true,
    this.overScrollEnabled = true,
    this.pullToRefreshEnabled = false,
    this.domStorageEnabled = true,
    this.allowFileAccess = false,
    this.allowContentAccess = false,
    this.mixedContentMode = WebViewMixedContentMode.neverAllow,
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

  /// Keeps cookies, cache and storage in memory only, so nothing is written to
  /// disk and the data is gone when the controller is disposed.
  ///
  /// iOS only, creation only (`WKWebsiteDataStore.nonPersistent()`). Android's
  /// WebView shares cookies, cache and storage across the whole app, so the
  /// setting is ignored there.
  final bool incognito;

  /// Lets scripts call `window.open` without a user gesture. When `false`,
  /// `window.open` only works in response to a tap or click.
  final bool javaScriptCanOpenWindowsAutomatically;

  /// Shows scroll bars (Android) or scroll indicators (iOS) while scrolling.
  final bool scrollbarsVisible;

  /// Allows scrolling past the content edge: the stretch / glow effect on
  /// Android and the bounce on iOS.
  final bool overScrollEnabled;

  /// Reloads the page when the user pulls down from the top, with the
  /// platform's refresh indicator (`SwipeRefreshLayout` on Android,
  /// `UIRefreshControl` on iOS). The indicator stops when the page finishes
  /// loading or fails.
  ///
  /// On iOS it needs [overScrollEnabled], because the pull is a bounce.
  final bool pullToRefreshEnabled;

  /// Lets pages use `localStorage` and `sessionStorage`. Android only
  /// (`WebSettings.setDomStorageEnabled`); WKWebView always allows them.
  final bool domStorageEnabled;

  /// Lets pages and loads reach `file://` URLs. Android only
  /// (`WebSettings.setAllowFileAccess`). Off by default: a page that can read
  /// local files can leak app data. iOS has no equivalent.
  final bool allowFileAccess;

  /// Lets the WebView load `content://` URLs from content providers. Android
  /// only (`WebSettings.setAllowContentAccess`). Off by default for the same
  /// reason as [allowFileAccess]. iOS has no equivalent.
  final bool allowContentAccess;

  /// What happens to HTTP content on an HTTPS page. Android only
  /// (`WebSettings.setMixedContentMode`); WKWebView blocks it and has no
  /// setting.
  final WebViewMixedContentMode mixedContentMode;

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
    bool? incognito,
    bool? javaScriptCanOpenWindowsAutomatically,
    bool? scrollbarsVisible,
    bool? overScrollEnabled,
    bool? pullToRefreshEnabled,
    bool? domStorageEnabled,
    bool? allowFileAccess,
    bool? allowContentAccess,
    WebViewMixedContentMode? mixedContentMode,
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
      incognito: incognito ?? this.incognito,
      javaScriptCanOpenWindowsAutomatically:
          javaScriptCanOpenWindowsAutomatically ??
          this.javaScriptCanOpenWindowsAutomatically,
      scrollbarsVisible: scrollbarsVisible ?? this.scrollbarsVisible,
      overScrollEnabled: overScrollEnabled ?? this.overScrollEnabled,
      pullToRefreshEnabled: pullToRefreshEnabled ?? this.pullToRefreshEnabled,
      domStorageEnabled: domStorageEnabled ?? this.domStorageEnabled,
      allowFileAccess: allowFileAccess ?? this.allowFileAccess,
      allowContentAccess: allowContentAccess ?? this.allowContentAccess,
      mixedContentMode: mixedContentMode ?? this.mixedContentMode,
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
    incognito: incognito,
    javaScriptCanOpenWindowsAutomatically:
        javaScriptCanOpenWindowsAutomatically,
    scrollbarsVisible: scrollbarsVisible,
    overScrollEnabled: overScrollEnabled,
    pullToRefreshEnabled: pullToRefreshEnabled,
    domStorageEnabled: domStorageEnabled,
    allowFileAccess: allowFileAccess,
    allowContentAccess: allowContentAccess,
    mixedContentMode: MixedContentModeMessage.values[mixedContentMode.index],
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
      other.incognito == incognito &&
      other.javaScriptCanOpenWindowsAutomatically ==
          javaScriptCanOpenWindowsAutomatically &&
      other.scrollbarsVisible == scrollbarsVisible &&
      other.overScrollEnabled == overScrollEnabled &&
      other.pullToRefreshEnabled == pullToRefreshEnabled &&
      other.domStorageEnabled == domStorageEnabled &&
      other.allowFileAccess == allowFileAccess &&
      other.allowContentAccess == allowContentAccess &&
      other.mixedContentMode == mixedContentMode &&
      other.minimumFontSize == minimumFontSize &&
      other.userAgent == userAgent;

  @override
  int get hashCode => Object.hashAll([
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
    incognito,
    javaScriptCanOpenWindowsAutomatically,
    scrollbarsVisible,
    overScrollEnabled,
    pullToRefreshEnabled,
    domStorageEnabled,
    allowFileAccess,
    allowContentAccess,
    mixedContentMode,
    minimumFontSize,
    userAgent,
  ]);
}
