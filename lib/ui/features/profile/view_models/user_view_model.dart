import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/models/article.dart';
import '../../../../data/models/collection.dart';
import '../../../../data/models/highlight.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../data/repositories/user_repository.dart';

class UserViewModel extends ChangeNotifier {
  final UserRepository _userRepository;
  String _themeMode = 'light'; // 'light', 'sepia', 'dark'
  double _fontSize = 18.0;

  UserViewModel({required UserRepository userRepository}) : _userRepository = userRepository {
    _loadPreferences();
  }

  UserProfile get profile => _userRepository.profile;
  List<Article> get savedArticles => _userRepository.savedArticles;
  List<Collection> get collections => _userRepository.collections;
  List<Highlight> get highlights => _userRepository.highlights;
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
    await _userRepository.updateRegion(region);
    notifyListeners();
  }

  Future<void> addMutedKeyword(String keyword) async {
    await _userRepository.addMutedKeyword(keyword);
    notifyListeners();
  }

  Future<void> removeMutedKeyword(String keyword) async {
    await _userRepository.removeMutedKeyword(keyword);
    notifyListeners();
  }

  Future<void> updatePaperPriority(String paper, int priority) async {
    await _userRepository.updatePaperPriority(paper, priority);
    notifyListeners();
  }

  Future<void> togglePaper(String paper, bool enabled) async {
    await _userRepository.togglePaper(paper, enabled);
    notifyListeners();
  }

  Future<void> followAuthor(String author) async {
    await _userRepository.followAuthor(author);
    notifyListeners();
  }

  Future<void> unfollowAuthor(String author) async {
    await _userRepository.unfollowAuthor(author);
    notifyListeners();
  }

  Future<void> addSearchQuery(String query) async {
    await _userRepository.addSearchQuery(query);
    notifyListeners();
  }

  Future<void> clearSearchHistory() async {
    await _userRepository.clearSearchHistory();
    notifyListeners();
  }

  Future<void> saveArticle(Article article) async {
    await _userRepository.saveArticle(article);
    notifyListeners();
  }

  Future<void> unsaveArticle(String articleId) async {
    await _userRepository.unsaveArticle(articleId);
    notifyListeners();
  }

  Future<void> updateArticleProgress(Article article, double progress) async {
    await _userRepository.updateArticleProgress(article, progress);
    notifyListeners();
  }

  Future<void> toggleReadLater(Article article, bool isReadLater) async {
    await _userRepository.toggleReadLater(article, isReadLater);
    notifyListeners();
  }

  Future<void> createCollection(String name, int color, {List<String> tags = const []}) async {
    await _userRepository.createCollection(name, color, tags: tags);
    notifyListeners();
  }

  Future<void> deleteCollection(String id) async {
    await _userRepository.deleteCollection(id);
    notifyListeners();
  }

  Future<void> addArticleToCollection(String collectionId, String articleId) async {
    await _userRepository.addArticleToCollection(collectionId, articleId);
    notifyListeners();
  }

  Future<void> removeArticleFromCollection(String collectionId, String articleId) async {
    await _userRepository.removeArticleFromCollection(collectionId, articleId);
    notifyListeners();
  }

  List<Highlight> getHighlightsForArticle(String articleId) {
    return _userRepository.getHighlightsForArticle(articleId);
  }

  Future<void> addHighlight(String articleId, String passageText, String noteText) async {
    await _userRepository.addHighlight(articleId, passageText, noteText);
    notifyListeners();
  }

  Future<void> removeHighlight(String highlightId) async {
    await _userRepository.removeHighlight(highlightId);
    notifyListeners();
  }
  
  Future<void> forceArchiveScan() async {
    await _userRepository.autoArchiveOldArticles();
    notifyListeners();
  }
}
