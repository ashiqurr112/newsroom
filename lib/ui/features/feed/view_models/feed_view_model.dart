import 'package:flutter/material.dart';
import 'package:newsroom/data/models/article.dart';
import 'package:newsroom/data/models/user_profile.dart';
import 'package:newsroom/data/repositories/feed_repository.dart';

class FeedViewModel extends ChangeNotifier {
  final FeedRepository feedRepository;
  List<Article> _articles = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _searchQuery = '';
  String _lengthFilter = 'All'; // 'All', 'Short', 'Medium', 'Long'

  FeedViewModel({required this.feedRepository});

  List<Article> get articles {
    var list = List<Article>.from(_articles);

    // Apply length filter
    if (_lengthFilter != 'All') {
      if (_lengthFilter == 'Short') {
        list = list.where((a) => a.estimatedReadingTime <= 4).toList();
      } else if (_lengthFilter == 'Medium') {
        list = list.where((a) => a.estimatedReadingTime >= 5 && a.estimatedReadingTime <= 10).toList();
      } else if (_lengthFilter == 'Long') {
        list = list.where((a) => a.estimatedReadingTime > 10).toList();
      }
    }

    // Apply search query filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) {
        return a.title.toLowerCase().contains(q) ||
               a.author.toLowerCase().contains(q) ||
               a.description.toLowerCase().contains(q) ||
               a.source.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get lengthFilter => _lengthFilter;

  Future<void> fetchFeed({required UserProfile profile, bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _articles = await feedRepository.getFeed(profile: profile, forceRefresh: forceRefresh);
      if (_articles.isEmpty) {
        _errorMessage = 'No articles found. Check your internet connection or feed settings.';
      }
    } catch (e) {
      _errorMessage = 'Failed to load feeds: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setLengthFilter(String filter) {
    _lengthFilter = filter;
    notifyListeners();
  }
}
