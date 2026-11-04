import 'package:flutter/foundation.dart';

/// A file the WebView was about to download.
///
/// The WebView does not save the file. Fetch [url] yourself, for example with
/// an HTTP client that sends the cookies from
/// [AdvancedWebViewController.getCookies], or hand it to the system browser.
@immutable
class DownloadRequest {
  const DownloadRequest({
    required this.url,
    this.suggestedFilename,
    this.mimeType,
    this.contentLength,
  });

  /// Where the file is served. `blob:` and `data:` URLs are passed through as
  /// they are and cannot be fetched outside the page.
  final String url;

  /// File name from `Content-Disposition` or the URL, when there is one.
  final String? suggestedFilename;

  final String? mimeType;

  /// Size in bytes, or `null` when the server did not say.
  final int? contentLength;

  @override
  String toString() =>
      'DownloadRequest($url, $suggestedFilename, $mimeType, $contentLength)';
}

/// Called when the page starts a download.
typedef DownloadStartCallback = void Function(DownloadRequest request);
