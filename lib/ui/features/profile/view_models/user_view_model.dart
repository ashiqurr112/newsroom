import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:newsroom/data/models/article.dart';
import 'package:newsroom/data/models/collection.dart';
import 'package:newsroom/data/models/highlight.dart';
import 'package:newsroom/data/models/user_profile.dart';
import 'package:newsroom/data/repositories/user_repository.dart';

class UserViewModel extends ChangeNotifier {
  final UserRepository userRepository;
  String _themeMode = 'light'; // 'light', 'sepia', 'dark'
  double _fontSize = 18.0;

  UserViewModel({required this.userRepository}) {
    _loadPreferences();
  }

  UserProfile get profile => userRepository.profile;
  List<Article> get savedArticles => userRepository.savedArticles;
  List<Collection> get collections => userRepository.collections;
  List<Highlight> get highlights => userRepository.highlights;
  String get themeMode => _themeMode;
  double get fontSize => _fontSize;

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _themeMode = prefs.getString('theme_mode') ?? 'light';
      _fontSize = prefs.getDouble('font_size') ?? 18.0;
      notifyListeners();
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', mode);
    } catch (e) {
      print('Error saving theme mode: $e');
    }
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('font_size', size);
    } catch (e) {
      print('Error saving font size: $e');
    }
  }

  // Delegated Repository Operations
  Future<void> updateRegion(String region) async {
    await userRepository.updateRegion(region);
    notifyListeners();
  }

  Future<void> addMutedKeyword(String keyword) async {
    await userRepository.addMutedKeyword(keyword);
    notifyListeners();
  }

  Future<void> removeMutedKeyword(String keyword) async {
    await userRepository.removeMutedKeyword(keyword);
    notifyListeners();
  }

  Future<void> updatePaperPriority(String paper, int priority) async {
    await userRepository.updatePaperPriority(paper, priority);
    notifyListeners();
  }

  Future<void> togglePaper(String paper, bool enabled) async {
    await userRepository.togglePaper(paper, enabled);
    notifyListeners();
  }

  Future<void> followAuthor(String author) async {
    await userRepository.followAuthor(author);
    notifyListeners();
  }

  Future<void> unfollowAuthor(String author) async {
    await userRepository.unfollowAuthor(author);
    notifyListeners();
  }

  Future<void> addSearchQuery(String query) async {
    await userRepository.addSearchQuery(query);
    notifyListeners();
  }

  Future<void> clearSearchHistory() async {
    await userRepository.clearSearchHistory();
    notifyListeners();
  }

  Future<void> saveArticle(Article article) async {
    await userRepository.saveArticle(article);
    notifyListeners();
  }

  Future<void> unsaveArticle(String articleId) async {
    await userRepository.unsaveArticle(articleId);
    notifyListeners();
  }

  Future<void> updateArticleProgress(Article article, double progress) async {
    await userRepository.updateArticleProgress(article, progress);
    notifyListeners();
  }

  Future<void> updateArticleImageUrl(Article article, String imageUrl) async {
    await userRepository.updateArticleImageUrl(article, imageUrl);
    notifyListeners();
  }

  Future<void> updateArticleContent(Article article, List<ArticleContentBlock> bodyContent, String? imageUrl) async {
    await userRepository.updateArticleContent(article, bodyContent, imageUrl);
    notifyListeners();
  }


  Future<void> toggleReadLater(Article article, bool isReadLater) async {
    await userRepository.toggleReadLater(article, isReadLater);
    notifyListeners();
  }

  Future<void> createCollection(String name, int color, {List<String> tags = const []}) async {
    await userRepository.createCollection(name, color, tags: tags);
    notifyListeners();
  }

  Future<void> deleteCollection(String id) async {
    await userRepository.deleteCollection(id);
    notifyListeners();
  }

  Future<void> addArticleToCollection(String collectionId, String articleId) async {
    await userRepository.addArticleToCollection(collectionId, articleId);
    notifyListeners();
  }

  Future<void> removeArticleFromCollection(String collectionId, String articleId) async {
    await userRepository.removeArticleFromCollection(collectionId, articleId);
    notifyListeners();
  }

  List<Highlight> getHighlightsForArticle(String articleId) {
    return userRepository.getHighlightsForArticle(articleId);
  }

  Future<void> addHighlight(String articleId, String passageText, String noteText) async {
    await userRepository.addHighlight(articleId, passageText, noteText);
    notifyListeners();
  }

  Future<void> removeHighlight(String highlightId) async {
    await userRepository.removeHighlight(highlightId);
    notifyListeners();
  }
  
  Future<void> forceArchiveScan() async {
    await userRepository.autoArchiveOldArticles();
    notifyListeners();
  }
}
