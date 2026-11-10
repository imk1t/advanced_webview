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

/// Which appearance an iOS WebView uses, and so whether pages see
/// `prefers-color-scheme: dark`.
enum WebViewUserInterfaceStyle {
  /// Follows the app (the system setting unless the app overrides it).
  unspecified,

  /// Always light.
  light,

  /// Always dark.
  dark,
}

/// Which version of a site the WebView asks for (iOS only).
enum WebViewContentMode {
  /// Lets WebKit choose for the device: mobile sites on iPhone, desktop sites
  /// on iPad.
  recommended,

  /// Asks for the mobile version of sites.
  mobile,

  /// Asks for the desktop version of sites.
  desktop,
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

/// Settings that only apply on Android.
///
/// Pass it as [WebViewSettings.android]. iOS ignores every field.
@immutable
class AndroidWebViewSettings {
  const AndroidWebViewSettings({
    this.supportZoom = true,
    this.builtInZoomControls = true,
    this.displayZoomControls = false,
    this.passkeysEnabled = false,
    this.domStorageEnabled = true,
    this.allowFileAccess = false,
    this.allowContentAccess = false,
    this.mixedContentMode = WebViewMixedContentMode.neverAllow,
    this.geolocationEnabled = true,
    this.algorithmicDarkeningAllowed = false,
    this.thirdPartyCookiesEnabled = false,
    this.safeBrowsingEnabled = true,
  });

  /// Lets the user pinch to zoom (`WebSettings.setSupportZoom`).
  final bool supportZoom;

  /// Lets the user zoom with pinch and double-tap gestures
  /// (`WebSettings.setBuiltInZoomControls`). WebView needs this together with
  /// [supportZoom] for pinch zoom to work, so turn either off to disable it.
  /// iOS has no setting; page zoom follows the page's viewport.
  final bool builtInZoomControls;

  /// Shows the on-screen `+` / `-` zoom buttons
  /// (`WebSettings.setDisplayZoomControls`). Only has an effect when
  /// [builtInZoomControls] is on. iOS has no such buttons.
  final bool displayZoomControls;

  /// Enables WebAuthn / passkeys for web content loaded in the WebView
  /// (`WebSettingsCompat.setWebAuthenticationSupport`; a no-op when the
  /// installed WebView does not support it).
  ///
  /// The site's domain must be associated with the app through Digital Asset
  /// Links. On iOS, WKWebView supports passkeys whenever the app has the
  /// Associated Domains `webcredentials:` entitlement for the site's domain,
  /// so there is no setting.
  final bool passkeysEnabled;

  /// Lets pages use `localStorage` and `sessionStorage`
  /// (`WebSettings.setDomStorageEnabled`). WKWebView always allows them.
  final bool domStorageEnabled;

  /// Lets pages and loads reach `file://` URLs
  /// (`WebSettings.setAllowFileAccess`). Off by default: a page that can read
  /// local files can leak app data. iOS has no equivalent.
  final bool allowFileAccess;

  /// Lets the WebView load `content://` URLs from content providers
  /// (`WebSettings.setAllowContentAccess`). Off by default for the same reason
  /// as [allowFileAccess]. iOS has no equivalent.
  final bool allowContentAccess;

  /// What happens to HTTP content on an HTTPS page
  /// (`WebSettings.setMixedContentMode`). WKWebView blocks it and has no
  /// setting.
  final WebViewMixedContentMode mixedContentMode;

  /// Lets pages use `navigator.geolocation`
  /// (`WebSettings.setGeolocationEnabled`). On by default, as in earlier
  /// versions. Turn it off to refuse location requests without asking.
  ///
  /// Even when on, the page only gets a location if the app holds the Android
  /// location permission and the request is granted through
  /// [AdvancedWebViewController.onPermissionRequest]. On iOS the system decides,
  /// so there is no setting.
  final bool geolocationEnabled;

  /// Lets the WebView darken pages that do not support a dark theme
  /// (`WebSettingsCompat.setAlgorithmicDarkeningAllowed`). Off by default.
  ///
  /// It only darkens while the app theme is dark (for example `Theme.Material3.DayNight`
  /// with the system in dark mode); pages that declare `color-scheme: dark`
  /// themselves are left alone. It has no effect when the installed WebView
  /// does not support the feature. iOS has no equivalent; see
  /// [IOSWebViewSettings.userInterfaceStyle] for `prefers-color-scheme`.
  final bool algorithmicDarkeningAllowed;

  /// Accepts cookies that a page's embedded content (an iframe or an image,
  /// for example) sets for another site
  /// (`CookieManager.setAcceptThirdPartyCookies`). Off by default, which is
  /// the platform's own default. Turn it on for embedded sign-in or payment
  /// frames that need them. iOS has no equivalent: WebKit decides.
  final bool thirdPartyCookiesEnabled;

  /// Checks pages against Google's list of dangerous sites and warns before
  /// showing one (`WebSettings.setSafeBrowsingEnabled`). On by default, as in
  /// earlier versions. Needs Android 8.0 (API 26) and a WebView that supports
  /// it, and is ignored otherwise. iOS has no switch: WebKit's fraudulent
  /// website warning is always on.
  final bool safeBrowsingEnabled;

  AndroidWebViewSettings copyWith({
    bool? supportZoom,
    bool? builtInZoomControls,
    bool? displayZoomControls,
    bool? passkeysEnabled,
    bool? domStorageEnabled,
    bool? allowFileAccess,
    bool? allowContentAccess,
    WebViewMixedContentMode? mixedContentMode,
    bool? geolocationEnabled,
    bool? algorithmicDarkeningAllowed,
    bool? thirdPartyCookiesEnabled,
    bool? safeBrowsingEnabled,
  }) {
    return AndroidWebViewSettings(
      supportZoom: supportZoom ?? this.supportZoom,
      builtInZoomControls: builtInZoomControls ?? this.builtInZoomControls,
      displayZoomControls: displayZoomControls ?? this.displayZoomControls,
      passkeysEnabled: passkeysEnabled ?? this.passkeysEnabled,
      domStorageEnabled: domStorageEnabled ?? this.domStorageEnabled,
      allowFileAccess: allowFileAccess ?? this.allowFileAccess,
      allowContentAccess: allowContentAccess ?? this.allowContentAccess,
      mixedContentMode: mixedContentMode ?? this.mixedContentMode,
      geolocationEnabled: geolocationEnabled ?? this.geolocationEnabled,
      algorithmicDarkeningAllowed:
          algorithmicDarkeningAllowed ?? this.algorithmicDarkeningAllowed,
      thirdPartyCookiesEnabled:
          thirdPartyCookiesEnabled ?? this.thirdPartyCookiesEnabled,
      safeBrowsingEnabled: safeBrowsingEnabled ?? this.safeBrowsingEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AndroidWebViewSettings &&
      other.supportZoom == supportZoom &&
      other.builtInZoomControls == builtInZoomControls &&
      other.displayZoomControls == displayZoomControls &&
      other.passkeysEnabled == passkeysEnabled &&
      other.domStorageEnabled == domStorageEnabled &&
      other.allowFileAccess == allowFileAccess &&
      other.allowContentAccess == allowContentAccess &&
      other.mixedContentMode == mixedContentMode &&
      other.geolocationEnabled == geolocationEnabled &&
      other.algorithmicDarkeningAllowed == algorithmicDarkeningAllowed &&
      other.thirdPartyCookiesEnabled == thirdPartyCookiesEnabled &&
      other.safeBrowsingEnabled == safeBrowsingEnabled;

  @override
  int get hashCode => Object.hash(
    supportZoom,
    builtInZoomControls,
    displayZoomControls,
    passkeysEnabled,
    domStorageEnabled,
    allowFileAccess,
    allowContentAccess,
    mixedContentMode,
    geolocationEnabled,
    algorithmicDarkeningAllowed,
    thirdPartyCookiesEnabled,
    safeBrowsingEnabled,
  );
}

/// Settings that only apply on iOS.
///
/// Pass it as [WebViewSettings.ios]. Android ignores every field. Settings
/// marked "creation only" are ignored by
/// [AdvancedWebViewController.updateSettings].
@immutable
class IOSWebViewSettings {
  const IOSWebViewSettings({
    this.allowsInlineMediaPlayback = false,
    this.allowsBackForwardNavigationGestures = false,
    this.incognito = false,
    this.applicationNameForUserAgent,
    this.contentMode = WebViewContentMode.recommended,
    this.allowsLinkPreview = true,
    this.userInterfaceStyle = WebViewUserInterfaceStyle.unspecified,
  });

  /// Plays videos inline instead of full screen
  /// (`WKWebViewConfiguration.allowsInlineMediaPlayback`). Creation only.
  final bool allowsInlineMediaPlayback;

  /// Lets the user swipe from the screen edge to go back and forward
  /// (`allowsBackForwardNavigationGestures`). Android's WebView has no
  /// equivalent.
  final bool allowsBackForwardNavigationGestures;

  /// Keeps cookies, cache and storage in memory only, so nothing is written to
  /// disk and the data is gone when the controller is disposed
  /// (`WKWebsiteDataStore.nonPersistent()`). Creation only.
  ///
  /// Android's WebView shares cookies, cache and storage across the whole app,
  /// so there is no equivalent.
  final bool incognito;

  /// Text appended to the default user agent, after the version
  /// (`WKWebViewConfiguration.applicationNameForUserAgent`). Creation only.
  ///
  /// Unlike [WebViewSettings.userAgent], it keeps the platform's own user
  /// agent and only adds a token, e.g. `MyApp/1.0`. It has no effect while
  /// [WebViewSettings.userAgent] is set. `null` uses the platform default.
  /// Android has no equivalent; use [WebViewSettings.userAgent] there.
  final String? applicationNameForUserAgent;

  /// Whether sites are asked for their mobile or desktop version
  /// (`WKWebpagePreferences.preferredContentMode`). Takes effect on the next
  /// navigation. An explicit [WebViewSettings.userAgent] takes precedence over
  /// it. Android has no equivalent; use [WebViewSettings.userAgent] there.
  final WebViewContentMode contentMode;

  /// Shows the link preview when the user presses and holds a link
  /// (`WKWebView.allowsLinkPreview`). Android has no equivalent.
  final bool allowsLinkPreview;

  /// Forces the light or dark appearance for this WebView
  /// (`UIView.overrideUserInterfaceStyle`), which decides whether pages match
  /// `prefers-color-scheme: dark`. [WebViewUserInterfaceStyle.unspecified]
  /// follows the app. Android has no equivalent; see
  /// [AndroidWebViewSettings.algorithmicDarkeningAllowed].
  final WebViewUserInterfaceStyle userInterfaceStyle;

  IOSWebViewSettings copyWith({
    bool? allowsInlineMediaPlayback,
    bool? allowsBackForwardNavigationGestures,
    bool? incognito,
    ValueGetter<String?>? applicationNameForUserAgent,
    WebViewContentMode? contentMode,
    bool? allowsLinkPreview,
    WebViewUserInterfaceStyle? userInterfaceStyle,
  }) {
    return IOSWebViewSettings(
      allowsInlineMediaPlayback:
          allowsInlineMediaPlayback ?? this.allowsInlineMediaPlayback,
      allowsBackForwardNavigationGestures:
          allowsBackForwardNavigationGestures ??
          this.allowsBackForwardNavigationGestures,
      incognito: incognito ?? this.incognito,
      applicationNameForUserAgent: applicationNameForUserAgent != null
          ? applicationNameForUserAgent()
          : this.applicationNameForUserAgent,
      contentMode: contentMode ?? this.contentMode,
      allowsLinkPreview: allowsLinkPreview ?? this.allowsLinkPreview,
      userInterfaceStyle: userInterfaceStyle ?? this.userInterfaceStyle,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is IOSWebViewSettings &&
      other.allowsInlineMediaPlayback == allowsInlineMediaPlayback &&
      other.allowsBackForwardNavigationGestures ==
          allowsBackForwardNavigationGestures &&
      other.incognito == incognito &&
      other.applicationNameForUserAgent == applicationNameForUserAgent &&
      other.contentMode == contentMode &&
      other.allowsLinkPreview == allowsLinkPreview &&
      other.userInterfaceStyle == userInterfaceStyle;

  @override
  int get hashCode => Object.hash(
    allowsInlineMediaPlayback,
    allowsBackForwardNavigationGestures,
    incognito,
    applicationNameForUserAgent,
    contentMode,
    allowsLinkPreview,
    userInterfaceStyle,
  );
}

/// Per-WebView settings.
///
/// The fields here work on both platforms. Options that exist on one platform
/// only live in [android] and [ios]; the other platform ignores them.
@immutable
class WebViewSettings {
  const WebViewSettings({
    this.javaScriptEnabled = true,
    this.mediaPlaybackRequiresUserGesture = true,
    this.transparentBackground = false,
    this.inspectable = false,
    this.textZoom = 100,
    this.cacheMode = WebViewCacheMode.normal,
    this.javaScriptCanOpenWindowsAutomatically = true,
    this.scrollbarsVisible = true,
    this.overScrollEnabled = true,
    this.pullToRefreshEnabled = false,
    this.minimumFontSize,
    this.userAgent,
    this.android = const AndroidWebViewSettings(),
    this.ios = const IOSWebViewSettings(),
  }) : assert(textZoom > 0, 'textZoom must be positive'),
       assert(
         minimumFontSize == null || minimumFontSize >= 0,
         'minimumFontSize must not be negative',
       );

  final bool javaScriptEnabled;

  /// Creation only on iOS.
  final bool mediaPlaybackRequiresUserGesture;

  final bool transparentBackground;

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

  /// Smallest font size the WebView renders: sp on Android
  /// (`WebSettings.setMinimumFontSize`), pt on iOS
  /// (`WKPreferences.minimumFontSize`). `null` uses the platform default.
  final int? minimumFontSize;

  /// `null` uses the platform default user agent.
  final String? userAgent;

  /// Android-only settings; iOS ignores them.
  final AndroidWebViewSettings android;

  /// iOS-only settings; Android ignores them.
  final IOSWebViewSettings ios;

  WebViewSettings copyWith({
    bool? javaScriptEnabled,
    bool? mediaPlaybackRequiresUserGesture,
    bool? transparentBackground,
    bool? inspectable,
    int? textZoom,
    WebViewCacheMode? cacheMode,
    bool? javaScriptCanOpenWindowsAutomatically,
    bool? scrollbarsVisible,
    bool? overScrollEnabled,
    bool? pullToRefreshEnabled,
    ValueGetter<int?>? minimumFontSize,
    ValueGetter<String?>? userAgent,
    AndroidWebViewSettings? android,
    IOSWebViewSettings? ios,
  }) {
    return WebViewSettings(
      javaScriptEnabled: javaScriptEnabled ?? this.javaScriptEnabled,
      mediaPlaybackRequiresUserGesture:
          mediaPlaybackRequiresUserGesture ??
          this.mediaPlaybackRequiresUserGesture,
      transparentBackground:
          transparentBackground ?? this.transparentBackground,
      inspectable: inspectable ?? this.inspectable,
      textZoom: textZoom ?? this.textZoom,
      cacheMode: cacheMode ?? this.cacheMode,
      javaScriptCanOpenWindowsAutomatically:
          javaScriptCanOpenWindowsAutomatically ??
          this.javaScriptCanOpenWindowsAutomatically,
      scrollbarsVisible: scrollbarsVisible ?? this.scrollbarsVisible,
      overScrollEnabled: overScrollEnabled ?? this.overScrollEnabled,
      pullToRefreshEnabled: pullToRefreshEnabled ?? this.pullToRefreshEnabled,
      minimumFontSize: minimumFontSize != null
          ? minimumFontSize()
          : this.minimumFontSize,
      userAgent: userAgent != null ? userAgent() : this.userAgent,
      android: android ?? this.android,
      ios: ios ?? this.ios,
    );
  }

  WebViewSettingsMessage toMessage() => WebViewSettingsMessage(
    javaScriptEnabled: javaScriptEnabled,
    mediaPlaybackRequiresUserGesture: mediaPlaybackRequiresUserGesture,
    allowsInlineMediaPlayback: ios.allowsInlineMediaPlayback,
    supportZoom: android.supportZoom,
    builtInZoomControls: android.builtInZoomControls,
    displayZoomControls: android.displayZoomControls,
    transparentBackground: transparentBackground,
    passkeysEnabled: android.passkeysEnabled,
    allowsBackForwardNavigationGestures:
        ios.allowsBackForwardNavigationGestures,
    inspectable: inspectable,
    textZoom: textZoom,
    cacheMode: CacheModeMessage.values[cacheMode.index],
    incognito: ios.incognito,
    javaScriptCanOpenWindowsAutomatically:
        javaScriptCanOpenWindowsAutomatically,
    scrollbarsVisible: scrollbarsVisible,
    overScrollEnabled: overScrollEnabled,
    pullToRefreshEnabled: pullToRefreshEnabled,
    domStorageEnabled: android.domStorageEnabled,
    allowFileAccess: android.allowFileAccess,
    allowContentAccess: android.allowContentAccess,
    mixedContentMode:
        MixedContentModeMessage.values[android.mixedContentMode.index],
    contentMode: ContentModeMessage.values[ios.contentMode.index],
    allowsLinkPreview: ios.allowsLinkPreview,
    geolocationEnabled: android.geolocationEnabled,
    algorithmicDarkeningAllowed: android.algorithmicDarkeningAllowed,
    thirdPartyCookiesEnabled: android.thirdPartyCookiesEnabled,
    safeBrowsingEnabled: android.safeBrowsingEnabled,
    userInterfaceStyle:
        UserInterfaceStyleMessage.values[ios.userInterfaceStyle.index],
    minimumFontSize: minimumFontSize,
    userAgent: userAgent,
    applicationNameForUserAgent: ios.applicationNameForUserAgent,
  );

  @override
  bool operator ==(Object other) =>
      other is WebViewSettings &&
      other.javaScriptEnabled == javaScriptEnabled &&
      other.mediaPlaybackRequiresUserGesture ==
          mediaPlaybackRequiresUserGesture &&
      other.transparentBackground == transparentBackground &&
      other.inspectable == inspectable &&
      other.textZoom == textZoom &&
      other.cacheMode == cacheMode &&
      other.javaScriptCanOpenWindowsAutomatically ==
          javaScriptCanOpenWindowsAutomatically &&
      other.scrollbarsVisible == scrollbarsVisible &&
      other.overScrollEnabled == overScrollEnabled &&
      other.pullToRefreshEnabled == pullToRefreshEnabled &&
      other.minimumFontSize == minimumFontSize &&
      other.userAgent == userAgent &&
      other.android == android &&
      other.ios == ios;

  @override
  int get hashCode => Object.hashAll([
    javaScriptEnabled,
    mediaPlaybackRequiresUserGesture,
    transparentBackground,
    inspectable,
    textZoom,
    cacheMode,
    javaScriptCanOpenWindowsAutomatically,
    scrollbarsVisible,
    overScrollEnabled,
    pullToRefreshEnabled,
    minimumFontSize,
    userAgent,
    android,
    ios,
  ]);
}
