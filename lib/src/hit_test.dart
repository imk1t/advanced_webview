import 'package:flutter/foundation.dart';

/// What [WebViewHitTestResult] found under a point.
enum WebViewHitTestType {
  /// Neither a link nor an image.
  none,

  /// A link (`<a href>`), possibly around text.
  link,

  /// An image (`<img>`) that is not inside a link.
  image,

  /// An image inside a link.
  imageLink,
}

/// The outcome of [AdvancedWebViewController.hitTest].
@immutable
class WebViewHitTestResult {
  const WebViewHitTestResult({this.linkUrl, this.imageUrl});

  /// Absolute URL of the enclosing link, or `null`.
  final String? linkUrl;

  /// Absolute URL of the image, or `null`.
  final String? imageUrl;

  WebViewHitTestType get type => switch ((linkUrl, imageUrl)) {
    (null, null) => WebViewHitTestType.none,
    (_, null) => WebViewHitTestType.link,
    (null, _) => WebViewHitTestType.image,
    _ => WebViewHitTestType.imageLink,
  };

  @internal
  factory WebViewHitTestResult.fromJson(Object? json) {
    if (json is! Map) return const WebViewHitTestResult();
    String? string(String key) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return WebViewHitTestResult(
      linkUrl: string('link'),
      imageUrl: string('image'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WebViewHitTestResult &&
      other.linkUrl == linkUrl &&
      other.imageUrl == imageUrl;

  @override
  int get hashCode => Object.hash(linkUrl, imageUrl);

  @override
  String toString() =>
      'WebViewHitTestResult(linkUrl: $linkUrl, imageUrl: $imageUrl)';
}

/// JavaScript that returns `{link, image}` for the element at [x], [y].
@internal
String hitTestScript(double x, double y) =>
    '(function(x, y) {'
    ' var e = document.elementFromPoint(x, y), link = null, image = null;'
    ' while (e) {'
    " if (!image && e.tagName === 'IMG') image = e.currentSrc || e.src;"
    " if (!link && e.tagName === 'A' && e.href) link = e.href;"
    ' e = e.parentElement;'
    ' }'
    ' return {link: link, image: image};'
    '})($x, $y)';
