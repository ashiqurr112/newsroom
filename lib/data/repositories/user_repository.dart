import 'package:uuid/uuid.dart';
import '../models/article.dart';
import '../models/collection.dart';
import '../models/highlight.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';

class UserRepository {
  final StorageService _storageService;
  final Uuid _uuid = const Uuid();

  UserProfile _profile = UserProfile();
  List<Article> _savedArticles = [];
  List<Collection> _collections = [];
  List<Highlight> _highlights = [];

  UserRepository(this._storageService);

  UserProfile get profile => _profile;
  List<Article> get savedArticles => _savedArticles;
  List<Collection> get collections => _collections;
  List<Highlight> get highlights => _highlights;

  Future<void> init() async {
    _profile = await _storageService.loadUserProfile();
    _savedArticles = await _storageService.loadSavedArticles();
    _collections = await _storageService.loadCollections();
    _highlights = await _storageService.loadHighlights();
    
    // Auto-archive older articles on start
    await autoArchiveOldArticles();
  }

  // --- Profile / Preferences ---
  Future<void> updateProfile(UserProfile newProfile) async {
    _profile = newProfile;
    await _storageService.saveUserProfile(_profile);
  }

  Future<void> updateRegion(String region) async {
    await updateProfile(_profile.copyWith(selectedRegion: region));
  }

  Future<void> addMutedKeyword(String keyword) async {
    final cleanKeyword = keyword.trim();
    if (cleanKeyword.isEmpty || _profile.mutedKeywords.contains(cleanKeyword)) return;
    final updatedKeywords = List<String>.from(_profile.mutedKeywords)..add(cleanKeyword);
    await updateProfile(_profile.copyWith(mutedKeywords: updatedKeywords));
  }

  Future<void> removeMutedKeyword(String keyword) async {
    final updatedKeywords = List<String>.from(_profile.mutedKeywords)..remove(keyword);
    await updateProfile(_profile.copyWith(mutedKeywords: updatedKeywords));
  }

  Future<void> updatePaperPriority(String paper, int priority) async {
    final updatedPriorities = Map<String, int>.from(_profile.paperPriorities)..[paper] = priority;
    await updateProfile(_profile.copyWith(paperPriorities: updatedPriorities));
  }

  Future<void> togglePaper(String paper, bool enabled) async {
    final updatedEnabled = Map<String, bool>.from(_profile.enabledPapers)..[paper] = enabled;
    await updateProfile(_profile.copyWith(enabledPapers: updatedEnabled));
  }

  Future<void> followAuthor(String author) async {
    final cleanAuthor = author.trim();
    if (cleanAuthor.isEmpty || _profile.followedAuthors.contains(cleanAuthor)) return;
    final updated = List<String>.from(_profile.followedAuthors)..add(cleanAuthor);
    await updateProfile(_profile.copyWith(followedAuthors: updated));
  }

  Future<void> unfollowAuthor(String author) async {
    final updated = List<String>.from(_profile.followedAuthors)..remove(author);
    await updateProfile(_profile.copyWith(followedAuthors: updated));
  }

  Future<void> addSearchQuery(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    final updated = List<String>.from(_profile.searchHistory)..remove(clean);
    updated.insert(0, clean); // Move to top
    if (updated.length > 20) updated.removeLast(); // Cap history length
    await updateProfile(_profile.copyWith(searchHistory: updated));
  }

  Future<void> clearSearchHistory() async {
    await updateProfile(_profile.copyWith(searchHistory: []));
  }

  // --- Saved Articles ---
  Future<void> saveArticle(Article article) async {
    if (_savedArticles.any((a) => a.id == article.id)) {
      _savedArticles = _savedArticles.map((a) {
        if (a.id == article.id) {
          return a.copyWith(isSaved: true, savedDate: DateTime.now());
        }
        return a;
      }).toList();
    } else {
      _savedArticles.add(article.copyWith(isSaved: true, savedDate: DateTime.now()));
    }
    await _storageService.saveSavedArticles(_savedArticles);
  }

  Future<void> unsaveArticle(String articleId) async {
    for (final col in _collections) {
      if (col.articleIds.contains(articleId)) {
        await removeArticleFromCollection(col.id, articleId);
      }
    }
    _savedArticles = _savedArticles.where((a) => a.id != articleId).toList();
    await _storageService.saveSavedArticles(_savedArticles);
  }

  Future<void> updateArticleProgress(Article article, double progress) async {
    final wasCompletedBefore = article.readProgress >= 0.9;
    final isCompletedNow = progress >= 0.9;

    if (_savedArticles.any((a) => a.id == article.id)) {
      _savedArticles = _savedArticles.map((a) => a.id == article.id ? a.copyWith(readProgress: progress) : a).toList();
      await _storageService.saveSavedArticles(_savedArticles);
    }

    if (isCompletedNow && !wasCompletedBefore) {
      await recordReadActivity();
    }
  }

  // --- Read Later Queue ---
  Future<void> toggleReadLater(Article article, bool isReadLater) async {
    if (_savedArticles.any((a) => a.id == article.id)) {
      _savedArticles = _savedArticles.map((a) => a.id == article.id ? a.copyWith(isReadLater: isReadLater) : a).toList();
    } else if (isReadLater) {
      _savedArticles.add(article.copyWith(isReadLater: true));
    }
    await _storageService.saveSavedArticles(_savedArticles);
  }

  // --- Collections ---
  Future<void> createCollection(String name, int color, {List<String> tags = const []}) async {
    final col = Collection(
      id: _uuid.v4(),
      name: name,
      color: color,
      articleIds: [],
      tags: tags,
    );
    _collections.add(col);
    await _storageService.saveCollections(_collections);
  }

  Future<void> deleteCollection(String id) async {
    _collections = _collections.where((c) => c.id != id).toList();
    await _storageService.saveCollections(_collections);
  }

  Future<void> addArticleToCollection(String collectionId, String articleId) async {
    _collections = _collections.map((c) {
      if (c.id == collectionId && !c.articleIds.contains(articleId)) {
        return c.copyWith(articleIds: List<String>.from(c.articleIds)..add(articleId));
      }
      return c;
    }).toList();
    await _storageService.saveCollections(_collections);
  }

  Future<void> removeArticleFromCollection(String collectionId, String articleId) async {
    _collections = _collections.map((c) {
      if (c.id == collectionId) {
        return c.copyWith(articleIds: List<String>.from(c.articleIds)..remove(articleId));
      }
      return c;
    }).toList();
    await _storageService.saveCollections(_collections);
  }

  // --- Highlights & Notes ---
  List<Highlight> getHighlightsForArticle(String articleId) {
    return _highlights.where((h) => h.articleId == articleId).toList();
  }

  Future<void> addHighlight(String articleId, String passageText, String noteText) async {
    final highlight = Highlight(
      id: _uuid.v4(),
      articleId: articleId,
      passageText: passageText,
      noteText: noteText,
      createdAt: DateTime.now(),
    );
    _highlights.add(highlight);
    await _storageService.saveHighlights(_highlights);
  }

  Future<void> removeHighlight(String highlightId) async {
    _highlights = _highlights.where((h) => h.id != highlightId).toList();
    await _storageService.saveHighlights(_highlights);
  }

  // --- Streak Tracker ---
  Future<void> recordReadActivity() async {
    final todayStr = _formatDate(DateTime.now());
    if (_profile.readDates.contains(todayStr)) return;

    final updatedReadDates = List<String>.from(_profile.readDates)..add(todayStr);
    
    int newStreak = _profile.streakCount;
    final yesterdayStr = _formatDate(DateTime.now().subtract(const Duration(days: 1)));

    if (_profile.streakCount == 0) {
      newStreak = 1;
    } else if (_profile.lastReadDate == yesterdayStr) {
      newStreak += 1;
    } else if (_profile.lastReadDate != todayStr) {
      newStreak = 1; // Streak broken, reset
    }

    await updateProfile(_profile.copyWith(
      streakCount: newStreak,
      lastReadDate: todayStr,
      readDates: updatedReadDates,
    ));
  }

  // --- Auto-Archive older saved articles ---
  Future<void> autoArchiveOldArticles() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    bool changed = false;

    _savedArticles = _savedArticles.map((a) {
      if (a.isSaved && !a.isArchived && a.savedDate != null && a.savedDate!.isBefore(cutoff)) {
        changed = true;
        return a.copyWith(isArchived: true);
      }
      return a;
    }).toList();

    if (changed) {
      await _storageService.saveSavedArticles(_savedArticles);
    }
  }

  String _formatDate(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }
}
