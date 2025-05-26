import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:convert';

const String url = 'https://skanuj-staging.web.app/coupons?company_name=klepierre-demo';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb && Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  
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
  const WebViewScaffold({super.key, required this.url});

  @override
  State<WebViewScaffold> createState() => _WebViewScaffoldState();
}

class _WebViewScaffoldState extends State<WebViewScaffold> {
  InAppWebViewController? _controller;

  @override
  void initState() {
    super.initState();
    // Request camera permission immediately when the widget is created
    _requestInitialCameraPermission();
  }

  Future<void> _requestInitialCameraPermission() async {
    try {
      debugPrint('Requesting initial camera permission...');
      final cameraStatus = await Permission.camera.status;
      
      if (cameraStatus.isDenied || cameraStatus.isRestricted) {
        debugPrint('Camera permission not granted, requesting...');
        final result = await Permission.camera.request();
        debugPrint('Camera permission result: $result');
      } else if (cameraStatus.isGranted) {
        debugPrint('Camera permission already granted');
      }
    } catch (e) {
      debugPrint('Error requesting camera permission: $e');
    }
  }

  void _injectJavaScript() {
    final String jsCode = '''
(function() {
  console.log('JavaScript injection started');
  
  // Hide UI elements
  function hideElements() {
    var loginButton = document.querySelector('#close-widget-login-button');
    if (loginButton) {
      loginButton.style.display = 'none';
    }
    var closeButton = document.querySelector('.close-widget-btn');
    if (closeButton) {
      closeButton.style.display = 'none';
    }
  }
  
  hideElements();
  
  // Watch for new elements
  var observer = new MutationObserver(hideElements);
  observer.observe(document.body, { childList: true, subtree: true });
  
  // ONLY intercept direct file input clicks - nothing else
  document.addEventListener('click', function(e) {
    // Only handle actual file input elements
    if (e.target && e.target.type === 'file') {
      console.log('File input clicked, preventing default and calling Flutter');
      e.preventDefault();
      e.stopPropagation();
      
      // Store reference to the file input
      window.currentFileInput = e.target;
      
      // Call Flutter file picker
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('FilePicker', 'pick_file');
      }
    }
  }, true);
  
  console.log('JavaScript injection completed');
})();
''';

    _controller?.evaluateJavascript(source: jsCode);
  }

  Future<void> _handleFilePicker() async {
    try {
      debugPrint('File picker triggered from JavaScript');
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        allowCompression: true,
      );

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.first;
        String fileName = file.name;
        String? filePath = file.path;
        
        if (filePath != null) {
          debugPrint('File selected: $fileName at $filePath');
          
          File selectedFile = File(filePath);
          List<int> fileBytes = await selectedFile.readAsBytes();
          String base64String = base64Encode(fileBytes);
          String mimeType = _getMimeType(fileName);
          
          // Inject the file into the web page
          await _controller?.evaluateJavascript(source: """
            (function() {
              try {
                var fileInput = window.currentFileInput || document.querySelector('input[type="file"]');
                
                if (fileInput) {
                  console.log('Injecting file into input:', '$fileName');
                  
                  var byteCharacters = atob('$base64String');
                  var byteNumbers = new Array(byteCharacters.length);
                  for (var i = 0; i < byteCharacters.length; i++) {
                    byteNumbers[i] = byteCharacters.charCodeAt(i);
                  }
                  var byteArray = new Uint8Array(byteNumbers);
                  var blob = new Blob([byteArray], {type: '$mimeType'});
                  
                  var file = new File([blob], '$fileName', { type: '$mimeType' });
                  
                  var dataTransfer = new DataTransfer();
                  dataTransfer.items.add(file);
                  fileInput.files = dataTransfer.files;
                  
                  // Trigger events
                  var changeEvent = new Event('change', { bubbles: true });
                  fileInput.dispatchEvent(changeEvent);
                  
                  var inputEvent = new Event('input', { bubbles: true });
                  fileInput.dispatchEvent(inputEvent);
                  
                  console.log('File injected successfully:', '$fileName');
                } else {
                  console.error('No file input found to inject file into');
                }
              } catch (error) {
                console.error('Error injecting file:', error);
              }
            })();
          """);
        }
      } else {
        debugPrint('No file selected');
      }
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  String _getMimeType(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          allowsInlineMediaPlayback: true,
          mediaPlaybackRequiresUserGesture: false,
          allowsBackForwardNavigationGestures: true,
          supportZoom: false,
          userAgent: Platform.isIOS 
              ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1'
              : 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
          allowsLinkPreview: false,
          isFraudulentWebsiteWarningEnabled: false,
          clearCache: false,
          cacheEnabled: true,
          transparentBackground: false,
        ),
        onWebViewCreated: (controller) {
          _controller = controller;
          
          // Add JavaScript handler for file picker
          controller.addJavaScriptHandler(
            handlerName: 'FilePicker',
            callback: (args) async {
              if (args.isNotEmpty && args[0] == 'pick_file') {
                await _handleFilePicker();
              }
            },
          );
        },
        onLoadStart: (controller, url) {
          debugPrint('Loading: $url');
        },
        onLoadStop: (controller, url) {
          debugPrint('Loaded: $url');
          Future.delayed(Duration(milliseconds: 500), () {
            _injectJavaScript();
          });
        },
        onReceivedError: (controller, request, error) {
          debugPrint('Error: ${error.description}');
        },
        onConsoleMessage: (controller, consoleMessage) {
          debugPrint('Console: ${consoleMessage.message}');
        },
        onPermissionRequest: (controller, request) async {
          // Automatically grant ALL permissions - no checks, no logs, just grant
          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT,
          );
        },
      ),
    );
  }
}
