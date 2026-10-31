import 'package:flutter/foundation.dart';

import 'platform/messages.g.dart';

/// When a [UserScript] runs while a page loads.
enum UserScriptInjectionTime {
  /// Before the page's own scripts run.
  atDocumentStart,

  /// After the DOM has been parsed (`DOMContentLoaded`), before subresources
  /// such as images have finished loading.
  atDocumentEnd,
}

/// JavaScript that the WebView injects into every page it loads.
@immutable
class UserScript {
  const UserScript({
    required this.source,
    this.injectionTime = UserScriptInjectionTime.atDocumentStart,
    this.mainFrameOnly = true,
  });

  /// The JavaScript source to run.
  final String source;

  /// When the script runs. Defaults to [UserScriptInjectionTime.atDocumentStart].
  final UserScriptInjectionTime injectionTime;

  /// Whether the script only runs in the top-level frame. Defaults to `true`.
  final bool mainFrameOnly;

  /// @nodoc
  @internal
  UserScriptMessage toMessage() => UserScriptMessage(
    source: source,
    injectionTime: switch (injectionTime) {
      UserScriptInjectionTime.atDocumentStart =>
        UserScriptInjectionTimeMessage.atDocumentStart,
      UserScriptInjectionTime.atDocumentEnd =>
        UserScriptInjectionTimeMessage.atDocumentEnd,
    },
    mainFrameOnly: mainFrameOnly,
  );
}
