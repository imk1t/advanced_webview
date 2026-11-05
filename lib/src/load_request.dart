/// The HTTP method of [AdvancedWebViewController.loadRequest].
enum WebViewHttpMethod {
  get,

  /// Sends the body as a POST request. Android sends it as
  /// `application/x-www-form-urlencoded` and cannot add custom headers.
  post,
}
