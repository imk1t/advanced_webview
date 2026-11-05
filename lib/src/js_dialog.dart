import 'dart:async';

import 'package:flutter/foundation.dart';

/// The kind of JavaScript dialog a page opened.
enum JsDialogType {
  /// `window.alert(message)`: only an OK button.
  alert,

  /// `window.confirm(message)`: OK and Cancel; the page gets a `bool`.
  confirm,

  /// `window.prompt(message, defaultText)`: a text field with OK and Cancel;
  /// the page gets the text, or `null` when cancelled.
  prompt,
}

/// A JavaScript dialog the page is waiting on. The page's script is blocked
/// until the callback completes.
@immutable
class JsDialogRequest {
  const JsDialogRequest({
    required this.type,
    required this.message,
    required this.url,
    this.defaultText,
  });

  final JsDialogType type;

  /// The text the page passed to `alert`, `confirm` or `prompt`.
  final String message;

  /// URL of the page that opened the dialog.
  final String url;

  /// Initial value of a [JsDialogType.prompt] text field; `null` for the other
  /// types.
  final String? defaultText;

  @override
  String toString() => 'JsDialogRequest($type, $message, $url, $defaultText)';
}

/// How the app answered a [JsDialogRequest].
@immutable
class JsDialogResponse {
  /// The user pressed OK. For a [JsDialogType.prompt], [text] is what was
  /// entered; `null` returns [JsDialogRequest.defaultText], or an empty string
  /// when there is none.
  const JsDialogResponse.accept({this.text}) : accepted = true;

  /// The user pressed Cancel. `confirm` returns `false` and `prompt` returns
  /// `null` to the page. For an `alert` this just closes the dialog.
  const JsDialogResponse.dismiss() : accepted = false, text = null;

  final bool accepted;

  /// Text for a prompt; only used when [accepted].
  final String? text;

  @override
  String toString() => 'JsDialogResponse($accepted, $text)';
}

/// Shows or decides a JavaScript dialog and returns the answer. Errors count
/// as [JsDialogResponse.dismiss].
typedef JsDialogCallback = FutureOr<JsDialogResponse> Function(
  JsDialogRequest request,
);
