import 'package:flutter/foundation.dart';

/// Which `console` method produced a [WebViewConsoleMessage].
enum WebViewConsoleMessageLevel { debug, log, info, warning, error }

/// A call to `console.debug`, `log`, `info`, `warn` or `error` made by a page.
@immutable
class WebViewConsoleMessage {
  const WebViewConsoleMessage({
    required this.level,
    required this.message,
    this.sourceUrl,
    this.lineNumber,
  });

  final WebViewConsoleMessageLevel level;

  /// The logged arguments, formatted as text and joined with a space.
  final String message;

  /// Script that logged the message. Android only; `null` on iOS, where
  /// WebKit does not report it.
  final String? sourceUrl;

  /// Line in [sourceUrl]. Android only; `null` on iOS.
  final int? lineNumber;

  @override
  bool operator ==(Object other) =>
      other is WebViewConsoleMessage &&
      other.level == level &&
      other.message == message &&
      other.sourceUrl == sourceUrl &&
      other.lineNumber == lineNumber;

  @override
  int get hashCode => Object.hash(level, message, sourceUrl, lineNumber);

  @override
  String toString() =>
      'WebViewConsoleMessage(${level.name}, $message, $sourceUrl:$lineNumber)';
}

typedef ConsoleMessageCallback = void Function(WebViewConsoleMessage message);
