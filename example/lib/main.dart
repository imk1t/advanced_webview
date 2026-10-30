import 'package:advanced_webview/advanced_webview.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: BrowserPage()));

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  late final MobileWebViewController _controller;
  final _urlField = TextEditingController(text: 'https://flutter.dev');
  int _progress = 0;
  String? _title;

  @override
  void initState() {
    super.initState();
    _controller = MobileWebViewController(
      javaScriptChannels: {'Toaster': _showMessage},
      onProgress: (progress) => setState(() => _progress = progress),
      onTitleChanged: (title) => setState(() => _title = title),
      onPageStarted: (url) => _urlField.text = url,
      onWebResourceError: (error) => debugPrint('$error'),
      onNavigationRequest: (request) {
        // Example policy: block navigations to youtube.
        if (Uri.parse(request.url).host.endsWith('youtube.com')) {
          _showMessage('Blocked: ${request.url}');
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      },
    )..loadUrl(_urlField.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    _urlField.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runJavaScript() async {
    final result = await _controller.runJavaScriptReturningResult(
      'Toaster.postMessage("Hello from JS"); document.title',
    );
    _showMessage('Result: $result');
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) await _controller.goBack();
  }

  Future<void> _goForward() async {
    if (await _controller.canGoForward()) await _controller.goForward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title ?? 'advanced_webview'),
        actions: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _goForward,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _controller.reload,
          ),
          IconButton(icon: const Icon(Icons.code), onPressed: _runJavaScript),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: TextField(
              controller: _urlField,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: _controller.loadUrl,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
          Expanded(child: MobileWebView(controller: _controller)),
        ],
      ),
    );
  }
}
