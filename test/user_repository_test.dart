import 'package:flutter_test/flutter_test.dart';
import 'package:newsroom/data/models/article.dart';
import 'package:newsroom/data/models/collection.dart';
import 'package:newsroom/data/models/highlight.dart';
import 'package:newsroom/data/models/user_profile.dart';
import 'package:newsroom/data/services/storage_service.dart';
import 'package:newsroom/data/repositories/user_repository.dart';

// Fake storage service that stores data in memory instead of disk
class FakeStorageService implements StorageService {
  UserProfile profile = UserProfile();
  List<Article> savedArticles = [];
  List<Collection> collections = [];
  List<Highlight> highlights = [];

  @override
  Future<List<Article>> loadSavedArticles() async => savedArticles;

  @override
  Future<void> saveSavedArticles(List<Article> articles) async {
    savedArticles = articles;
  }

  @override
  Future<List<Collection>> loadCollections() async => collections;

  @override
  Future<void> saveCollections(List<Collection> cols) async {
    collections = cols;
  }

  @override
  Future<List<Highlight>> loadHighlights() async => highlights;

  @override
  Future<void> saveHighlights(List<Highlight> hls) async {
    highlights = hls;
  }

  @override
  Future<UserProfile> loadUserProfile() async => profile;

  @override
  Future<void> saveUserProfile(UserProfile prof) async {
    profile = prof;
  }
}

void main() {
  group('UserRepository Tests', () {
    late FakeStorageService fakeStorage;
    late UserRepository repository;

    final dummyArticle = Article(
      id: '123',
      title: 'AI Revolution',
      link: 'https://test.com/ai',
      description: 'AI is changing the world.',
      contentSnippet: 'AI is changing the world.',
      pubDate: DateTime.now(),
      author: 'John Doe',
      source: 'The New York Times',
      estimatedReadingTime: 5,
      region: 'US',
    );

    setUp(() {
      fakeStorage = FakeStorageService();
      repository = UserRepository(storageService: fakeStorage);
    });

    test('Initializes correctly and loads default values', () async {
      await repository.init();
      expect(repository.profile.streakCount, 0);
      expect(repository.savedArticles, isEmpty);
      expect(repository.collections, isEmpty);
    });

    test('Saving and unsaving articles works correctly', () async {
      await repository.init();
      await repository.saveArticle(dummyArticle);
      
      expect(repository.savedArticles.length, 1);
      expect(repository.savedArticles.first.id, '123');
      expect(repository.savedArticles.first.isSaved, isTrue);

      await repository.unsaveArticle('123');
      expect(repository.savedArticles, isEmpty);
    });

    test('Muted keywords updates profile correctly', () async {
      await repository.init();
      await repository.addMutedKeyword('crypto');
      expect(repository.profile.mutedKeywords, contains('crypto'));

      await repository.removeMutedKeyword('crypto');
      expect(repository.profile.mutedKeywords, isNot(contains('crypto')));
    });

    test('Reading streak logic computes correctly', () async {
      await repository.init();
      
      // Initial streak
      expect(repository.profile.streakCount, 0);

      // Record read today -> streak = 1
      await repository.recordReadActivity();
      expect(repository.profile.streakCount, 1);

      // Record read again today -> streak remains 1
      await repository.recordReadActivity();
      expect(repository.profile.streakCount, 1);
    });

    test('Auto-archive archives articles older than 30 days', () async {
      await repository.init();

      final oldArticle = dummyArticle.copyWith(
        id: '999',
        isSaved: true,
        savedDate: DateTime.now().subtract(const Duration(days: 35)),
      );

      fakeStorage.savedArticles = [oldArticle];
      
      // Re-initialize to trigger auto-archive check on init
      await repository.init();

      expect(repository.savedArticles.first.id, '999');
      expect(repository.savedArticles.first.isArchived, isTrue);
    });
  });
}
