/// Name of the JavaScript handler that carries `window.print()` calls.
const printHandlerName = '__advancedWebViewPrint';

/// Replaces `window.print()` so a call reaches the app instead of being ignored
/// (iOS) or opening the system print UI on its own (never, on Android).
///
/// The handler object is created by the handler bridge at document start; the
/// replacement looks it up when the page calls `print`, not before.
String printOverrideScript(String handlerObjectName) =>
    '''
(function () {
  if (window.__advancedWebViewPrint) return;
  window.__advancedWebViewPrint = true;
  window.print = function () {
    try {
      var bridge = window['$handlerObjectName'];
      var result = bridge && bridge.callHandler('$printHandlerName');
      if (result && result.catch) result.catch(function () {});
    } catch (e) {}
  };
})();
''';

/// The text the user selected in the page, including text selected in an
/// `<input>` or `<textarea>`.
const selectedTextScript = '''
(function () {
  var a = document.activeElement;
  if (a && (a.tagName === 'INPUT' || a.tagName === 'TEXTAREA') &&
      typeof a.selectionStart === 'number' && a.selectionStart !== a.selectionEnd) {
    try { return a.value.substring(a.selectionStart, a.selectionEnd); } catch (e) {}
  }
  return String(window.getSelection());
})()
''';

/// Collapses the selection, in the page and in a focused text field.
const clearSelectionScript = '''
(function () {
  var a = document.activeElement;
  if (a && (a.tagName === 'INPUT' || a.tagName === 'TEXTAREA') &&
      typeof a.selectionEnd === 'number') {
    try { a.setSelectionRange(a.selectionEnd, a.selectionEnd); } catch (e) {}
  }
  window.getSelection().removeAllRanges();
})()
''';
