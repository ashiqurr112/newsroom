import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:newsroom/data/models/article.dart';
import 'package:newsroom/data/services/feed_service.dart';

class WebViewScraperDialog extends StatefulWidget {
  final String articleUrl;
  final String source;

  const WebViewScraperDialog({
    super.key,
    required this.articleUrl,
    required this.source,
  });

  @override
  State<WebViewScraperDialog> createState() => _WebViewScraperDialogState();
}

class _WebViewScraperDialogState extends State<WebViewScraperDialog> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isCaptchaDetected = false;
  double _progress = 0.0;
  Timer? _checkTimer;
  bool _hasResult = false;

  @override
  void initState() {
    super.initState();
    
    // Construct the archive url. Clean query parameters to maximize hit rates.
    final cleanUrl = widget.articleUrl.split('?')[0];
    final archiveUrl = 'https://archive.is/$cleanUrl';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _progress = progress / 100.0;
              });
            }
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              _triggerScrapeCheck();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(archiveUrl));

    // Run a periodic check to auto-detect captcha completion
    _checkTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!_isLoading && !_hasResult && mounted) {
        _triggerScrapeCheck();
      }
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _triggerScrapeCheck() async {
    if (_hasResult || !mounted) return;

    try {
      const jsScript = '''
        (function() {
          var htmlContent = document.body.innerHTML.toLowerCase();
          var isCaptcha = document.getElementById('g-recaptcha') || 
                          document.querySelector('iframe[src*="recaptcha"]') || 
                          document.querySelector('.g-recaptcha') || 
                          htmlContent.indexOf('captcha-delivery') !== -1 ||
                          htmlContent.indexOf('captcha') !== -1;
          
          if (isCaptcha && !document.querySelector('article, main, div.n-layout__row--content, div[class*="article-body"]')) {
            return JSON.stringify({status: 'captcha'});
          }
          
          var selectors = [
            'div.n-layout__row--content',
            'div[style*="article-body"]',
            'article section',
            'div.article__body',
            'section[name="articleBody"]',
            'div.StoryBodyCompanionColumn',
            'article',
            'main'
          ];
          
          var container = null;
          for (var i = 0; i < selectors.length; i++) {
            var el = document.querySelector(selectors[i]);
            if (el && el.innerText.trim().length > 300) {
              container = el;
              break;
            }
          }
          
          if (!container) {
            container = document.querySelector('article') || document.querySelector('main');
          }
          
          if (container && container.innerText.trim().length > 150) {
            var blocks = [];
            var elements = container.querySelectorAll('p, figure img, div[style*="article-body"] p, div.n-layout__row--content p');
            if (elements.length === 0) {
              elements = container.querySelectorAll('p, img');
            }
            
            for (var j = 0; j < elements.length; j++) {
              var node = elements[j];
              if (node.tagName.toLowerCase() === 'p') {
                var text = node.innerText.trim();
                if (text.length > 10) {
                  blocks.push({type: 'text', value: text});
                }
              } else if (node.tagName.toLowerCase() === 'img') {
                var src = node.getAttribute('src') || node.getAttribute('currentsourceurl') || node.getAttribute('old-src');
                if (src && src.startsWith('http')) {
                  blocks.push({type: 'image', value: src});
                }
              }
            }
            
            var imageUrl = null;
            var ogImage = document.querySelector('meta[property="og:image"]');
            if (ogImage) {
              imageUrl = ogImage.getAttribute('content');
            }
            
            if (blocks.length > 0) {
              return JSON.stringify({
                status: 'success',
                imageUrl: imageUrl,
                blocks: blocks
              });
            }
          }
          
          return JSON.stringify({status: 'loading'});
        })()
      ''';

      final responseJsonStr = await _controller.runJavaScriptReturningResult(jsScript);
      
      // runJavaScriptReturningResult returns wrapped string (e.g. '"{\\"status\\":...}"' or 'null')
      if (responseJsonStr == null || responseJsonStr == 'null') return;
      
      // Clean string wrapper
      String cleanJson = responseJsonStr;
      if (cleanJson.startsWith('"') && cleanJson.endsWith('"')) {
        // Decode JS string literal
        cleanJson = jsonDecode(cleanJson) as String;
      }
      
      final Map<String, dynamic> result = jsonDecode(cleanJson);
      final status = result['status'] as String;

      if (status == 'captcha') {
        if (mounted && !_isCaptchaDetected) {
          setState(() {
            _isCaptchaDetected = true;
          });
        }
      } else if (status == 'success') {
        _hasResult = true;
        _checkTimer?.cancel();
        
        final imageUrl = result['imageUrl'] as String?;
        final rawBlocks = result['blocks'] as List<dynamic>;
        
        final List<ArticleContentBlock> blocks = rawBlocks.map((b) {
          return ArticleContentBlock(
            type: b['type'] as String,
            value: b['value'] as String,
          );
        }).toList();

        if (mounted) {
          Navigator.pop(context, FullArticleContent(
            bodyContent: blocks,
            imageUrl: imageUrl,
          ));
        }
      }
    } catch (e) {
      debugPrint('Scrape check exception: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF16181E) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Status Area
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.primaryColor.withAlpha((0.15 * 255).round()),
                      child: Icon(Icons.security_rounded, color: theme.primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isCaptchaDetected 
                              ? 'Security Check Required' 
                              : 'Bypassing Paywall...',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isCaptchaDetected
                              ? 'Please solve the captcha below to unlock.'
                              : 'Fetching full-text via secure archive...',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Cancel',
                    ),
                  ],
                ),
                if (!_isCaptchaDetected) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 4,
                      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // WebView viewport
          Flexible(
            child: Container(
              height: _isCaptchaDetected ? 450 : 1, // Minimize if no captcha, expand if captcha
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: WebViewWidget(controller: _controller),
              ),
            ),
          ),
          
          if (_isCaptchaDetected)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'The reader mode will automatically load as soon as you complete the verification.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            )
          else
            const SizedBox(height: 20),
        ],
      ),
    );
  }
}
