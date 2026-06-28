import 'package:newsroom/data/models/article.dart';
import 'package:newsroom/data/models/user_profile.dart';
import 'package:newsroom/data/services/feed_service.dart';

class FeedRepository {
  final FeedService feedService;

  FeedRepository({required this.feedService});

  static const Map<String, Map<String, String>> sources = {
    'The New York Times': {
      'url': 'https://rss.nytimes.com/services/xml/rss/nyt/Opinion.xml',
      'region': 'US',
    },
    'Financial Times': {
      'url': 'https://www.ft.com/opinion?format=rss',
      'region': 'Europe',
    },
    'The Independent': {
      'url': 'https://www.independent.co.uk/voices/rss',
      'region': 'Europe',
    },
    'The Guardian': {
      'url': 'https://www.theguardian.com/commentisfree/rss',
      'region': 'Europe',
    },
    'The Economist': {
      'url': 'https://www.economist.com/leaders/rss.xml',
      'region': 'Global',
    },
    'Project Syndicate': {
      'url': 'https://www.project-syndicate.org/rss',
      'region': 'Global',
    },
    'The Conversation': {
      'url': 'https://theconversation.com/global/articles.atom',
      'region': 'Global',
    },
    'BBC': {
      'url': 'https://feeds.bbci.co.uk/news/rss.xml',
      'region': 'Europe',
    },
    'Al Jazeera': {
      'url': 'https://www.aljazeera.com/xml/rss/all.xml',
      'region': 'South Asia',
    },
  };

  List<Article> _cachedArticles = [];
  DateTime? _lastFetchTime;

  List<Article> get cachedArticles => _cachedArticles;

  Future<List<Article>> getFeed({
    required UserProfile profile,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh && _cachedArticles.isNotEmpty && _lastFetchTime != null && now.difference(_lastFetchTime!).inMinutes < 10) {
      return _filterAndSortArticles(_cachedArticles, profile);
    }

    final List<Article> allArticles = [];
    final List<Future<List<Article>>> fetchFutures = [];

    sources.forEach((name, info) {
      final isEnabled = profile.enabledPapers[name] ?? true;
      if (isEnabled) {
        fetchFutures.add(feedService.fetchFeed(name, info['url']!, info['region']!));
      }
    });

    try {
      final List<List<Article>> results = await Future.wait(fetchFutures);
      for (final list in results) {
        allArticles.addAll(list);
      }
    } catch (e) {
      print('Error downloading feeds concurrently: $e');
    }

    if (allArticles.isNotEmpty) {
      _cachedArticles = allArticles;
      _lastFetchTime = now;
    }

    return _filterAndSortArticles(_cachedArticles, profile);
  }

  List<Article> _filterAndSortArticles(List<Article> articles, UserProfile profile) {
    var filtered = List<Article>.from(articles);

    // Filter by Region
    if (profile.selectedRegion != 'All') {
      filtered = filtered.where((a) => a.region.toLowerCase() == profile.selectedRegion.toLowerCase()).toList();
    }

    // Filter out muted keywords
    if (profile.mutedKeywords.isNotEmpty) {
      filtered = filtered.where((a) {
        final titleLower = a.title.toLowerCase();
        final snippetLower = a.contentSnippet.toLowerCase();
        return !profile.mutedKeywords.any((kw) {
          final kwLower = kw.toLowerCase();
          return titleLower.contains(kwLower) || snippetLower.contains(kwLower);
        });
      }).toList();
    }

    // Sort by priorities & date
    filtered.sort((a, b) {
      final prioA = profile.paperPriorities[a.source] ?? 0;
      final prioB = profile.paperPriorities[b.source] ?? 0;
      
      if (prioA != prioB) {
        return prioB.compareTo(prioA); // Descending priority
      }
      
      return b.pubDate.compareTo(a.pubDate); // Date descending
    });

    return filtered;
  }
}
