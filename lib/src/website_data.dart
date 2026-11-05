/// A kind of data websites store in the WebView, for
/// [AdvancedWebViewController.clearWebsiteData].
enum WebsiteDataType {
  /// The HTTP cache: cached responses and, on iOS, the in-memory cache.
  cache,

  /// `localStorage` and `sessionStorage`.
  ///
  /// Android cannot clear this separately from [indexedDb]; selecting either
  /// clears all DOM storage (see [AdvancedWebViewController.clearWebsiteData]).
  localStorage,

  /// IndexedDB databases. See [localStorage] for the Android caveat.
  indexedDb,
}
