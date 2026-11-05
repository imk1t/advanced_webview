import 'package:flutter/foundation.dart';

import 'platform/messages.g.dart';

/// Reports find progress: the zero-based index of the highlighted match, the
/// number of matches found so far and whether the count is final.
typedef FindResultCallback = void Function(
  int activeMatchIndex,
  int numberOfMatches,
  bool isDone,
);

/// The outcome of [AdvancedWebViewController.findText].
@immutable
class FindResult {
  const FindResult({
    required this.found,
    this.matchCount,
    this.activeMatchIndex,
  });

  /// Whether the page contains the query.
  final bool found;

  /// How many matches the page has. Best-effort on iOS, see
  /// [AdvancedWebViewController.onFindResult].
  final int? matchCount;

  /// Zero-based index of the highlighted match; `null` when there is none.
  /// Best-effort on iOS.
  final int? activeMatchIndex;

  @internal
  factory FindResult.fromMessage(FindResultMessage message) => FindResult(
    found: message.found,
    matchCount: message.matchCount,
    activeMatchIndex: message.activeMatchIndex,
  );

  @override
  bool operator ==(Object other) =>
      other is FindResult &&
      other.found == found &&
      other.matchCount == matchCount &&
      other.activeMatchIndex == activeMatchIndex;

  @override
  int get hashCode => Object.hash(found, matchCount, activeMatchIndex);

  @override
  String toString() =>
      'FindResult(found: $found, matchCount: $matchCount, '
      'activeMatchIndex: $activeMatchIndex)';
}
