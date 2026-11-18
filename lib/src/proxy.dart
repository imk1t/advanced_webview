/// The protocol spoken to a proxy server.
enum ProxyType {
  /// An HTTP proxy. It carries HTTP and HTTPS traffic (HTTPS through
  /// `CONNECT`).
  http,

  /// A SOCKS5 proxy.
  socks5,
}

/// A proxy server for the WebView's network traffic. Pass it to
/// `AdvancedWebViewController.setProxy`.
class ProxyConfig {
  const ProxyConfig({
    required this.host,
    required this.port,
    this.type = ProxyType.http,
    this.bypassHosts = const [],
  });

  /// Host name or IP address of the proxy server.
  final String host;

  /// Port of the proxy server, 1 to 65535.
  final int port;

  /// The protocol the proxy speaks. [ProxyType.http] by default.
  final ProxyType type;

  /// Domains that are reached directly instead of through the proxy, for
  /// example `localhost` or `example.com`. A domain also covers its subdomains.
  final List<String> bypassHosts;

  @override
  bool operator ==(Object other) =>
      other is ProxyConfig &&
      other.host == host &&
      other.port == port &&
      other.type == type &&
      _listEquals(other.bypassHosts, bypassHosts);

  @override
  int get hashCode =>
      Object.hash(host, port, type, Object.hashAll(bypassHosts));

  @override
  String toString() => 'ProxyConfig(${type.name}://$host:$port)';

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
