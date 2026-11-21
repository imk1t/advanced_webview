/// The kind of resource a [ContentBlockerRule] applies to.
enum ContentBlockerResourceType {
  /// A page (main frame or iframe).
  document,

  /// An image.
  image,

  /// A CSS style sheet.
  stylesheet,

  /// A script.
  script,

  /// A web font.
  font,

  /// Audio or video.
  media,

  /// Everything else, including `fetch` and `XMLHttpRequest` requests.
  other,
}

/// What a [ContentBlockerRule] does to a request or page.
enum ContentBlockerAction {
  /// Cancel the request.
  block,

  /// Hide the elements matching [ContentBlockerRule.selector] on matching
  /// pages.
  cssDisplayNone,
}

/// A rule for `AdvancedWebViewController.setContentBlockers`: block requests
/// whose URL matches [urlFilter], or hide elements on pages whose URL matches.
class ContentBlockerRule {
  /// Blocks requests whose URL matches [urlFilter], optionally only for the
  /// given [resourceTypes].
  const ContentBlockerRule.block({
    required this.urlFilter,
    this.resourceTypes = const [],
  }) : action = ContentBlockerAction.block,
       selector = null;

  /// Hides the elements matching the CSS [selector] on pages whose URL matches
  /// [urlFilter] (every page by default).
  const ContentBlockerRule.hideElements({
    required String this.selector,
    this.urlFilter = '.*',
  }) : action = ContentBlockerAction.cssDisplayNone,
       resourceTypes = const [];

  /// Regular expression matched against the full URL, case insensitive. iOS
  /// accepts the subset WebKit supports (no look-around or back-references);
  /// keep to that subset so a rule behaves the same on both platforms.
  final String urlFilter;

  /// The resource types a blocking rule applies to; empty means all of them.
  /// Android infers the type from the request (headers and file extension),
  /// so an unusual resource may count as [ContentBlockerResourceType.other].
  final List<ContentBlockerResourceType> resourceTypes;

  /// What the rule does.
  final ContentBlockerAction action;

  /// CSS selector of the elements to hide; only set for
  /// [ContentBlockerAction.cssDisplayNone].
  final String? selector;

  @override
  String toString() => 'ContentBlockerRule(${action.name} $urlFilter)';
}
