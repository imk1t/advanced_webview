import SafariServices
import UIKit

/// Presents `SFSafariViewController` for Dart and reports when the user dismisses it.
final class SystemBrowser: NSObject, SFSafariViewControllerDelegate {
  private let onClosed: (Int64) -> Void
  private var sessions: [ObjectIdentifier: Int64] = [:]

  init(onClosed: @escaping (Int64) -> Void) {
    self.onClosed = onClosed
  }

  func open(params: SystemBrowserParamsMessage, from presenter: UIViewController) throws {
    guard let url = URL(string: params.url),
      let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https"
    else {
      throw PigeonError(code: "invalid-url", message: "Invalid URL: \(params.url)", details: nil)
    }
    let controller = SFSafariViewController(url: url)
    controller.delegate = self
    if let argb = params.toolbarColor {
      controller.preferredBarTintColor = UIColor(
        red: CGFloat((argb >> 16) & 0xFF) / 255, green: CGFloat((argb >> 8) & 0xFF) / 255,
        blue: CGFloat(argb & 0xFF) / 255, alpha: CGFloat((argb >> 24) & 0xFF) / 255)
    }
    sessions[ObjectIdentifier(controller)] = params.sessionId
    presenter.present(controller, animated: true)
  }

  func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
    guard let sessionId = sessions.removeValue(forKey: ObjectIdentifier(controller)) else { return }
    onClosed(sessionId)
  }
}
