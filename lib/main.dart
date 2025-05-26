import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
const String url = 'https://skanuj-staging.web.app/coupons?company_name=klepierre-demo';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: kIsWeb
            ? Center(child: Text('Web not supported in this build'))
            : WebViewScaffold(url: url),
      ),
    );
  }
}


class WebViewScaffold extends StatefulWidget {
  final String url;
  const WebViewScaffold({required this.url});

  @override
  State<WebViewScaffold> createState() => _WebViewScaffoldState();
}

class _WebViewScaffoldState extends State<WebViewScaffold> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
            _controller.runJavaScript("""
  (function() {
    function hide() {
      var loginButton = document.querySelector('#close-widget-login-button');
      if (loginButton) loginButton.style.display = 'none';
      var closeButton = document.querySelector('.close-widget-btn');
      if (closeButton) closeButton.style.display = 'none';
    }
    hide();
    var observer = new MutationObserver(hide);
    observer.observe(document.body, { childList: true, subtree: true });
  })();
""");
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Web resource error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: WebViewWidget(controller: _controller),
    );
  }
}
