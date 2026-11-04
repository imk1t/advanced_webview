import UIKit
import WebKit

/// Full-screen in-app browser: a navigation bar and a toolbar around the WKWebView of an
/// `AdvancedWebView` that Dart created. The WebView outlives this controller; Dart disposes it
/// after `onClosed`.
final class InAppBrowserViewController: UIViewController {
  let browser: AdvancedWebView
  private let params: InAppBrowserParamsMessage
  private let onClosed: () -> Void

  private var observations: [NSKeyValueObservation] = []
  private var backItem: UIBarButtonItem?
  private var forwardItem: UIBarButtonItem?
  private let titleLabel = UILabel()
  private let urlLabel = UILabel()
  private var isFinished = false
  private var isPresented = false
  private var closeRequested = false

  init(browser: AdvancedWebView, params: InAppBrowserParamsMessage, onClosed: @escaping () -> Void)
  {
    self.browser = browser
    self.params = params
    self.onClosed = onClosed
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  /// Presents the browser full screen over `presenter`.
  func present(from presenter: UIViewController) {
    let navigation = UINavigationController(rootViewController: self)
    navigation.modalPresentationStyle = .fullScreen
    presenter.present(navigation, animated: true) { [weak self] in
      guard let self else { return }
      self.isPresented = true
      if self.closeRequested { self.close() }
    }
  }

  /// Dismisses the browser; the WebView stays alive.
  func close() {
    guard !isFinished else { return }
    guard isPresented else {
      // Still animating in; close as soon as the presentation completes.
      closeRequested = true
      return
    }
    guard let navigation = navigationController else {
      finish()
      return
    }
    navigation.dismiss(animated: true) { [weak self] in self?.finish() }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    let webView = browser.webView
    webView.removeFromSuperview()
    webView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(webView)
    NSLayoutConstraint.activate([
      webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
    configureBars()
    observe(webView)
    refresh()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setToolbarHidden(!params.showNavigationButtons, animated: false)
    if let argb = params.toolbarColor { applyToolbarColor(argb) }
  }

  private func configureBars() {
    let action = UIAction { [weak self] _ in self?.close() }
    if let label = params.closeButtonLabel {
      navigationItem.leftBarButtonItem = UIBarButtonItem(
        title: label, image: nil, primaryAction: action)
    } else {
      navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: action)
    }

    titleLabel.font = .preferredFont(forTextStyle: .headline)
    titleLabel.adjustsFontForContentSizeCategory = true
    urlLabel.font = .preferredFont(forTextStyle: .caption2)
    urlLabel.adjustsFontForContentSizeCategory = true
    urlLabel.textColor = .secondaryLabel
    let titleView = UIStackView(
      arrangedSubviews: params.showUrl ? [titleLabel, urlLabel] : [titleLabel])
    titleView.axis = .vertical
    titleView.alignment = .center
    navigationItem.titleView = titleView

    if params.showNavigationButtons {
      let webView = browser.webView
      let back = UIBarButtonItem(
        image: UIImage(systemName: "chevron.backward"),
        primaryAction: UIAction { _ in webView.goBack() })
      let forward = UIBarButtonItem(
        image: UIImage(systemName: "chevron.forward"),
        primaryAction: UIAction { _ in webView.goForward() })
      let reload = UIBarButtonItem(
        image: UIImage(systemName: "arrow.clockwise"),
        primaryAction: UIAction { _ in webView.reload() })
      backItem = back
      forwardItem = forward
      toolbarItems = [back, forward, UIBarButtonItem(systemItem: .flexibleSpace), reload]
    }
  }

  private func applyToolbarColor(_ argb: Int64) {
    let background = UIColor(
      red: CGFloat((argb >> 16) & 0xFF) / 255, green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255, alpha: CGFloat((argb >> 24) & 0xFF) / 255)
    var white: CGFloat = 0
    background.getWhite(&white, alpha: nil)
    let foreground: UIColor = white > 0.5 ? .black : .white

    let appearance = UINavigationBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = background
    navigationItem.standardAppearance = appearance
    navigationItem.scrollEdgeAppearance = appearance
    let toolbarAppearance = UIToolbarAppearance()
    toolbarAppearance.configureWithOpaqueBackground()
    toolbarAppearance.backgroundColor = background
    navigationController?.toolbar.standardAppearance = toolbarAppearance
    navigationController?.toolbar.scrollEdgeAppearance = toolbarAppearance
    navigationController?.navigationBar.tintColor = foreground
    navigationController?.toolbar.tintColor = foreground
    titleLabel.textColor = foreground
    urlLabel.textColor = foreground.withAlphaComponent(0.7)
  }

  private func observe(_ webView: WKWebView) {
    observations = [
      webView.observe(\.title) { [weak self] _, _ in self?.refresh() },
      webView.observe(\.url) { [weak self] _, _ in self?.refresh() },
      webView.observe(\.canGoBack) { [weak self] _, _ in self?.refresh() },
      webView.observe(\.canGoForward) { [weak self] _, _ in self?.refresh() },
    ]
  }

  private func refresh() {
    let webView = browser.webView
    titleLabel.text = params.toolbarTitle ?? webView.title ?? ""
    urlLabel.text = webView.url?.absoluteString
    backItem?.isEnabled = webView.canGoBack
    forwardItem?.isEnabled = webView.canGoForward
  }

  /// Releases the WebView and reports the browser as closed. Safe to call more than once.
  func finish() {
    guard !isFinished else { return }
    isFinished = true
    observations.removeAll()
    browser.webView.removeFromSuperview()
    onClosed()
  }
}
