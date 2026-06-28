import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:newsroom/data/models/article.dart';
import 'package:newsroom/data/models/highlight.dart';
import 'package:newsroom/ui/features/profile/view_models/user_view_model.dart';
import 'package:newsroom/ui/features/feed/view_models/feed_view_model.dart';
import 'package:newsroom/ui/core/themes.dart';
import 'package:newsroom/ui/core/browser_launcher.dart';
import 'package:newsroom/ui/features/reader/widgets/webview_scraper_dialog.dart';

class ReaderView extends StatefulWidget {
  final Article article;

  const ReaderView({super.key, required this.article});

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;
  String? _overriddenTheme; // null, 'light', 'sepia', 'dark'
  List<ArticleContentBlock>? _fullContentBlocks;
  bool _isLoadingFullText = true;
  String? _fullArticleImageUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _loadFullText();
  }

  Future<void> _loadFullText() async {
    setState(() {
      _isLoadingFullText = true;
    });

    final feedRepository = Provider.of<FeedViewModel>(context, listen: false).feedRepository;
    final userVM = Provider.of<UserViewModel>(context, listen: false);

    // Check offline cache (saved_articles.json / savedArticles list)
    final cachedArticle = userVM.savedArticles.firstWhere(
      (a) => a.id == widget.article.id && a.bodyContent != null && a.cachedDate != null,
      orElse: () => widget.article,
    );

    if (cachedArticle.bodyContent != null && cachedArticle.cachedDate != null) {
      final difference = DateTime.now().difference(cachedArticle.cachedDate!);
      if (difference.inDays < 7) {
        setState(() {
          _fullContentBlocks = cachedArticle.bodyContent;
          _fullArticleImageUrl = cachedArticle.imageUrl;
          _isLoadingFullText = false;
        });
        _restoreScrollProgress(userVM);
        return;
      }
    }

    try {
      var fullContent = await feedRepository.feedService.fetchFullArticle(widget.article.source, widget.article.link);

      // If direct request returned empty (due to paywall or Cloudflare block), fall back to client-side WebView scraper
      if (fullContent.bodyContent.isEmpty && (widget.article.source == 'Financial Times' || widget.article.source == 'The Wall Street Journal')) {
        if (mounted) {
          final webViewResult = await showDialog<FullArticleContent>(
            context: context,
            barrierDismissible: true,
            builder: (context) => WebViewScraperDialog(
              articleUrl: widget.article.link,
              source: widget.article.source,
            ),
          );
          if (webViewResult != null && webViewResult.bodyContent.isNotEmpty) {
            fullContent = webViewResult;
          }
        }
      }

      if (mounted) {
        List<ArticleContentBlock> blocks = [];
        if (fullContent.bodyContent.isNotEmpty) {
          blocks = fullContent.bodyContent;
        } else {
          blocks = _getParagraphBlocks();
        }

        setState(() {
          _fullContentBlocks = blocks;
          _fullArticleImageUrl = fullContent.imageUrl;
          _isLoadingFullText = false;
        });

        // Save downloaded content to persistent cache
        await userVM.updateArticleContent(widget.article, blocks, fullContent.imageUrl);

        _restoreScrollProgress(userVM);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fullContentBlocks = _getParagraphBlocks();
          _isLoadingFullText = false;
        });
      }
    }
  }

  void _restoreScrollProgress(UserViewModel userVM) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final savedArticle = userVM.savedArticles.firstWhere(
        (a) => a.id == widget.article.id,
        orElse: () => widget.article,
      );
      
      if (savedArticle.readProgress > 0.0 && savedArticle.readProgress < 0.95) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            final targetOffset = savedArticle.readProgress * _scrollController.position.maxScrollExtent;
            _scrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveProgress();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveProgress();
    }
  }

  void _saveProgress() {
    final userVM = Provider.of<UserViewModel>(context, listen: false);
    userVM.updateArticleProgress(widget.article, _scrollProgress);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    if (maxScroll <= 0) return;
    
    double progress = currentScroll / maxScroll;
    if (progress < 0.0) progress = 0.0;
    if (progress > 1.0) progress = 1.0;
    
    if ((progress - _scrollProgress).abs() > 0.01) {
      setState(() {
        _scrollProgress = progress;
      });
    }
  }

  ThemeData _getEffectiveTheme(BuildContext context, String currentGlobalTheme) {
    final themeToUse = _overriddenTheme ?? currentGlobalTheme;
    switch (themeToUse) {
      case 'sepia':
        return AppTheme.sepiaTheme;
      case 'dark':
        return AppTheme.darkTheme;
      default:
        return AppTheme.lightTheme;
    }
  }

  List<ArticleContentBlock> _getParagraphBlocks() {
    final snippet = widget.article.contentSnippet;
    if (snippet.isEmpty) {
      return [ArticleContentBlock(type: 'text', value: 'No article content text available.')];
    }
    
    // Split by double newlines or single newlines if no double newlines exist
    List<String> paras = snippet.split('\n\n');
    if (paras.length == 1) {
      paras = snippet.split('\n');
    }
    
    return paras
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .map((p) => ArticleContentBlock(type: 'text', value: p))
        .toList();
  }


  @override
  Widget build(BuildContext context) {
    final userVM = Provider.of<UserViewModel>(context);
    final theme = _getEffectiveTheme(context, userVM.themeMode);

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.article.source,
            style: theme.appBarTheme.titleTextStyle?.copyWith(fontSize: 16),
          ),
          actions: [
            // Open in Browser
            IconButton(
              icon: const Icon(Icons.language_rounded),
              tooltip: 'Open in Browser',
              onPressed: () => BrowserLauncher.launchArticle(widget.article.link),
            ),
            // Text Adjuster (Font Size Slider)
            IconButton(
              icon: const Icon(Icons.format_size_rounded),
              tooltip: 'Adjust Font Size',
              onPressed: () => _showFontSizeSheet(context, userVM),
            ),
            // Theme Switcher Overrides
            IconButton(
              icon: Icon(
                _overriddenTheme == 'dark' 
                  ? Icons.dark_mode_rounded 
                  : (_overriddenTheme == 'sepia' ? Icons.menu_book_rounded : Icons.light_mode_rounded)
              ),
              tooltip: 'Switch Theme Override',
              onPressed: () {
                setState(() {
                  if (_overriddenTheme == null) {
                    _overriddenTheme = 'sepia';
                  } else if (_overriddenTheme == 'sepia') {
                    _overriddenTheme = 'dark';
                  } else if (_overriddenTheme == 'dark') {
                    _overriddenTheme = 'light';
                  } else {
                    _overriddenTheme = null;
                  }
                });
              },
            ),
          ],
        ),
        body: SelectionArea(
          child: Stack(
            children: [
              // Scrollable text view
              ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 80),
                itemCount: _isLoadingFullText ? 3 : (_fullContentBlocks!.length + 2),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Title and metadata header
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.article.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 26,
                              height: 1.25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                'By ${widget.article.author}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${widget.article.pubDate.day}/${widget.article.pubDate.month}/${widget.article.pubDate.year}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(thickness: 1),
                          if (widget.article.imageUrl != null || _fullArticleImageUrl != null) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                widget.article.imageUrl ?? _fullArticleImageUrl!,
                                width: double.infinity,
                                height: 220,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 220,
                                    color: theme.brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade100,
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    );
                  }
  
                  if (_isLoadingFullText) {
                    if (index == 1) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 80.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Bypassing paywall & unlocking article...',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }
  
                  if (index == _fullContentBlocks!.length + 1) {
                    // Bottom options
                    return Padding(
                      padding: const EdgeInsets.only(top: 32.0),
                      child: Column(
                        children: [
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            'End of Clutter-Free reading mode.',
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => BrowserLauncher.launchArticle(widget.article.link),
                            icon: const Icon(Icons.open_in_browser_rounded),
                            label: const Text('Read Original on Website'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: widget.article.link));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Link copied to clipboard!')),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('Copy Article Link'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
  
                  // Block item
                  final block = _fullContentBlocks![index - 1];
  
                  if (block.type == 'image') {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          block.value,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              color: theme.brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade100,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }
  
                  // Paragraph Text block item
                  final paragraphText = block.value;
                  final highlights = userVM.getHighlightsForArticle(widget.article.id);
                  final highlight = highlights.firstWhere(
                    (h) => h.passageText == paragraphText,
                    orElse: () => Highlight(id: '', articleId: '', passageText: '', noteText: '', createdAt: DateTime.now()),
                  );
                  
                  final isHighlighted = highlight.id.isNotEmpty;
                  final hasNote = isHighlighted && highlight.noteText.isNotEmpty;
  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showParagraphOptions(context, userVM, paragraphText, highlight),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isHighlighted 
                            ? (theme.brightness == Brightness.dark 
                                ? Colors.yellow.withValues(alpha: 0.15) 
                                : const Color(0xFFFFF1C5))
                            : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isHighlighted
                            ? Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1)
                            : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              paragraphText,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: userVM.fontSize,
                              ),
                            ),
                            if (hasNote) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.brightness == Brightness.dark 
                                    ? Colors.white10 
                                    : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border(left: BorderSide(color: theme.primaryColor, width: 3)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.notes_rounded, size: 14, color: theme.primaryColor),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        highlight.noteText,
                                        style: TextStyle(
                                          fontSize: userVM.fontSize - 3,
                                          fontStyle: FontStyle.italic,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
  
              // Scroll indicator at the top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _scrollProgress,
                  minHeight: 3.5,
                  color: theme.colorScheme.secondary,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFontSizeSheet(BuildContext context, UserViewModel userVM) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reading Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Font Size'),
                  Row(
                    children: [
                      const Text('A', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Slider(
                          value: userVM.fontSize,
                          min: 14.0,
                          max: 28.0,
                          divisions: 7,
                          label: userVM.fontSize.round().toString(),
                          onChanged: (val) {
                            setModalState(() {
                              userVM.setFontSize(val);
                            });
                          },
                        ),
                      ),
                      const Text('A', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Default Global Theme'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _themeButton(context, userVM, 'light', 'Light', Colors.white, Colors.black),
                      _themeButton(context, userVM, 'sepia', 'Sepia', const Color(0xFFF4ECD8), const Color(0xFF433422)),
                      _themeButton(context, userVM, 'dark', 'Dark', const Color(0xFF121212), Colors.white),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _themeButton(BuildContext context, UserViewModel userVM, String mode, String label, Color bg, Color text) {
    final isSelected = userVM.themeMode == mode;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: bg,
        side: BorderSide(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
          width: isSelected ? 2.5 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => userVM.setThemeMode(mode),
      child: Text(
        label,
        style: TextStyle(color: text, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  void _showParagraphOptions(BuildContext context, UserViewModel userVM, String passageText, Highlight highlight) {
    final isHighlighted = highlight.id.isNotEmpty;
    final noteController = TextEditingController(text: highlight.noteText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isHighlighted ? 'Edit Highlight & Note' : 'Highlight Paragraph',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add a personal note or translation to this passage...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: passageText));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Paragraph copied to clipboard!')),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy Paragraph Text'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (isHighlighted)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            userVM.removeHighlight(highlight.id);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Highlight and note removed')),
                            );
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          label: const Text('Delete', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (isHighlighted) {
                            // Update highlight (we remove old one, add new updated one)
                            userVM.removeHighlight(highlight.id);
                          }
                          userVM.addHighlight(
                            widget.article.id,
                            passageText,
                            noteController.text.trim(),
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isHighlighted ? 'Note updated' : 'Paragraph highlighted')),
                          );
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: Text(isHighlighted ? 'Save' : 'Highlight'),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}
