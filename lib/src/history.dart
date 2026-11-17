/// One entry of a WebView's navigation history.
class WebViewHistoryItem {
  const WebViewHistoryItem({required this.url, this.title});

  final String url;

  /// The page title, or `null` when the page has none or the platform does not
  /// know it.
  final String? title;

  @override
  bool operator ==(Object other) =>
      other is WebViewHistoryItem && other.url == url && other.title == title;

  @override
  int get hashCode => Object.hash(url, title);

  @override
  String toString() => 'WebViewHistoryItem($url, title: $title)';
}

/// The navigation history of a WebView's main frame.
class WebViewBackForwardList {
  const WebViewBackForwardList({
    required this.items,
    required this.currentIndex,
  });

  /// Entries from the oldest to the newest.
  final List<WebViewHistoryItem> items;

  /// Index of the current entry in [items], or `-1` when the history is empty.
  final int currentIndex;

  /// The current entry, or `null` when the history is empty.
  WebViewHistoryItem? get current =>
      currentIndex >= 0 && currentIndex < items.length
      ? items[currentIndex]
      : null;

  @override
  String toString() => 'WebViewBackForwardList($currentIndex of $items)';
}
