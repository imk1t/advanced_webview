import 'package:flutter/foundation.dart';

import 'platform/messages.g.dart';

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

  /// How many matches the page has. `null` on iOS, which does not count.
  final int? matchCount;

  /// Zero-based index of the highlighted match. `null` on iOS.
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
