import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:newsroom/data/repositories/feed_repository.dart';
import 'package:newsroom/ui/features/profile/view_models/user_view_model.dart';
import 'package:newsroom/ui/features/feed/view_models/feed_view_model.dart';
import 'package:newsroom/ui/features/reader/views/reader_view.dart';

class FeedView extends StatefulWidget {
  const FeedView({super.key});

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshFeed(false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshFeed(bool force) {
    final userVM = Provider.of<UserViewModel>(context, listen: false);
    Provider.of<FeedViewModel>(context, listen: false).fetchFeed(
      profile: userVM.profile,
      forceRefresh: force,
    );
  }

  Color getSourceColor(String source) {
    switch (source) {
      case 'The New York Times':
        return const Color(0xFF1A1A1A);
      case 'Financial Times':
        return const Color(0xFF381519);
      case 'The Times':
      case 'The Independent':
        return const Color(0xFF0F1E36);
      case 'The Guardian':
        return const Color(0xFF005689);
      case 'The Economist':
        return const Color(0xFFD51A22);
      case 'Project Syndicate':
        return const Color(0xFF0E5B5B);
      case 'Reuters':
      case 'The Conversation':
        return const Color(0xFFDF5800);
      case 'BBC':
        return const Color(0xFF900B0B);
      case 'Al Jazeera':
        return const Color(0xFFE88A00);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedVM = Provider.of<FeedViewModel>(context);
    final userVM = Provider.of<UserViewModel>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Newsroom', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Feed Preferences',
            onPressed: () => _showPreferencesDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search title, author, source...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          feedVM.setSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => feedVM.setSearchQuery(val),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  userVM.addSearchQuery(val);
                }
              },
            ),
          ),

          // Search History suggestions (if query empty but search box has focus, or simple history row)
          if (userVM.profile.searchHistory.isNotEmpty && _searchController.text.isEmpty)
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: userVM.profile.searchHistory.length > 5 ? 5 : userVM.profile.searchHistory.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final query = userVM.profile.searchHistory[index];
                  return InputChip(
                    label: Text(query, style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      _searchController.text = query;
                      feedVM.setSearchQuery(query);
                    },
                    onDeleted: () => userVM.clearSearchHistory(),
                  );
                },
              ),
            ),

          const SizedBox(height: 4),

          // Region scroll row
          Container(
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['All', 'US', 'Europe', 'South Asia', 'Global'].map((region) {
                final isSelected = userVM.profile.selectedRegion == region;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(region),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        userVM.updateRegion(region);
                        // Refresh feed list
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _refreshFeed(false);
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Length Filter row
          Container(
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['All', 'Short', 'Medium', 'Long'].map((filter) {
                final isSelected = feedVM.lengthFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text('$filter Reads'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        feedVM.setLengthFilter(filter);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Main list or loading state
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _refreshFeed(true);
              },
              child: feedVM.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : feedVM.errorMessage.isNotEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    Text(feedVM.errorMessage, textAlign: TextAlign.center),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () => _refreshFeed(true),
                                      child: const Text('Try Again'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : feedVM.articles.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                                const Center(child: Text('No matching articles found.')),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: feedVM.articles.length,
                              itemBuilder: (context, index) {
                                final article = feedVM.articles[index];
                                final isSaved = userVM.savedArticles.any((a) => a.id == article.id && a.isSaved);
                                final isReadLater = userVM.savedArticles.any((a) => a.id == article.id && a.isReadLater);
                                final savedVer = userVM.savedArticles.firstWhere((a) => a.id == article.id, orElse: () => article);
                                final imageUrl = savedVer.imageUrl ?? article.imageUrl;
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 1.5,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ReaderView(article: savedVer),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (imageUrl != null)
                                          ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                            child: Image.network(
                                              imageUrl,
                                              height: 180,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Container(
                                                  height: 180,
                                                  color: theme.brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade100,
                                                  child: const Center(
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  // Source Badge
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: getSourceColor(article.source),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      article.source,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w800,
                                                        fontFamily: 'sans-serif',
                                                      ),
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${article.estimatedReadingTime} min read',
                                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                article.title,
                                                style: theme.textTheme.titleLarge?.copyWith(
                                                  fontSize: 20,
                                                  height: 1.3,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                article.author,
                                                style: const TextStyle(
                                                  fontStyle: FontStyle.italic,
                                                  color: Colors.grey,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                article.contentSnippet,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              
                                              // Progress indicator
                                              if (savedVer.readProgress > 0.0 && savedVer.readProgress < 0.9) ...[
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: LinearProgressIndicator(
                                                        value: savedVer.readProgress,
                                                        borderRadius: BorderRadius.circular(4),
                                                        minHeight: 4,
                                                        color: theme.primaryColor,
                                                        backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '${(savedVer.readProgress * 100).toInt()}% read',
                                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                              ],

                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      isReadLater ? Icons.watch_later_rounded : Icons.watch_later_outlined,
                                                      color: isReadLater ? theme.primaryColor : Colors.grey,
                                                    ),
                                                    tooltip: 'Read Later',
                                                    onPressed: () {
                                                      userVM.toggleReadLater(article, !isReadLater);
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(!isReadLater ? 'Added to Read Later' : 'Removed from Read Later'),
                                                          duration: const Duration(seconds: 1),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                      isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                                                      color: isSaved ? theme.primaryColor : Colors.grey,
                                                    ),
                                                    tooltip: 'Save Article',
                                                    onPressed: () {
                                                      if (isSaved) {
                                                        userVM.unsaveArticle(article.id);
                                                      } else {
                                                        userVM.saveArticle(article);
                                                      }
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(isSaved ? 'Article unsaved' : 'Article saved to bookmarks'),
                                                          duration: const Duration(seconds: 1),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPreferencesDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Consumer<UserViewModel>(
              builder: (context, userVM, _) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Feed Customization',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // Paper management
                    const Text(
                      'Papers Subscriptions & Priorities',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...FeedRepository.sources.keys.map((name) {
                      final isEnabled = userVM.profile.enabledPapers[name] ?? true;
                      final priority = userVM.profile.paperPriorities[name] ?? 0;
                      return Card(
                        child: ListTile(
                          title: Text(name),
                          leading: Checkbox(
                            value: isEnabled,
                            onChanged: (val) {
                              if (val != null) {
                                userVM.togglePaper(name, val);
                              }
                            },
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: isEnabled && priority > 0
                                    ? () => userVM.updatePaperPriority(name, priority - 1)
                                    : null,
                              ),
                              Text('$priority', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: isEnabled && priority < 5
                                    ? () => userVM.updatePaperPriority(name, priority + 1)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    
                    const Divider(height: 32),
                    
                    // Mute keywords
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Muted Keywords / Topics',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          onPressed: () => _showAddMuteKeywordDialog(context, userVM),
                        )
                      ],
                    ),
                    if (userVM.profile.mutedKeywords.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('No muted keywords. Articles with muted keywords will be hidden.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        children: userVM.profile.mutedKeywords.map((kw) {
                          return Chip(
                            label: Text(kw),
                            deleteIcon: const Icon(Icons.cancel, size: 16),
                            onDeleted: () => userVM.removeMutedKeyword(kw),
                          );
                        }).toList(),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    ).then((_) {
      // Refresh after closing configuration bottom sheet
      _refreshFeed(false);
    });
  }

  void _showAddMuteKeywordDialog(BuildContext context, UserViewModel userVM) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mute Keyword/Topic'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter keyword e.g. inflation, elections',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  userVM.addMutedKeyword(controller.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Mute'),
            ),
          ],
        );
      },
    );
  }
}
