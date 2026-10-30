import 'package:flutter/foundation.dart';

import 'platform/messages.g.dart';

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
    this.userAgent,
  });

  final bool javaScriptEnabled;

  /// Creation only on iOS.
  final bool mediaPlaybackRequiresUserGesture;

  /// iOS only, creation only.
  final bool allowsInlineMediaPlayback;

  /// Android only.
  final bool supportZoom;

  final bool transparentBackground;

  /// `null` uses the platform default user agent.
  final String? userAgent;

  WebViewSettings copyWith({
    bool? javaScriptEnabled,
    bool? mediaPlaybackRequiresUserGesture,
    bool? allowsInlineMediaPlayback,
    bool? supportZoom,
    bool? transparentBackground,
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
      userAgent: userAgent != null ? userAgent() : this.userAgent,
    );
  }

  WebViewSettingsMessage toMessage() => WebViewSettingsMessage(
    javaScriptEnabled: javaScriptEnabled,
    mediaPlaybackRequiresUserGesture: mediaPlaybackRequiresUserGesture,
    allowsInlineMediaPlayback: allowsInlineMediaPlayback,
    supportZoom: supportZoom,
    transparentBackground: transparentBackground,
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
      other.userAgent == userAgent;

  @override
  int get hashCode => Object.hash(
    javaScriptEnabled,
    mediaPlaybackRequiresUserGesture,
    allowsInlineMediaPlayback,
    supportZoom,
    transparentBackground,
    userAgent,
  );
}
