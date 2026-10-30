import Foundation

/// Maps Dart-allocated `webViewId`s to live native instances. Main thread only.
final class WebViewRegistry {
  private var instances: [Int64: AdvancedWebView] = [:]

  func add(_ instance: AdvancedWebView) throws {
    guard instances[instance.id] == nil else {
      throw PigeonError(
        code: "already-exists", message: "webViewId \(instance.id) is already in use",
        details: nil)
    }
    instances[instance.id] = instance
  }

  func get(_ id: Int64) throws -> AdvancedWebView {
    guard let instance = instances[id] else {
      throw PigeonError(code: "not-found", message: "No WebView with id \(id)", details: nil)
    }
    return instance
  }

  func remove(_ id: Int64) -> AdvancedWebView? {
    return instances.removeValue(forKey: id)
  }

  func removeAll() -> [AdvancedWebView] {
    defer { instances.removeAll() }
    return Array(instances.values)
  }
}
