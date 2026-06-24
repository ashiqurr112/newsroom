import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/article.dart';
import '../models/collection.dart';
import '../models/highlight.dart';
import '../models/user_profile.dart';

class StorageService {
  Future<File> _getFile(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$filename');
  }

  Future<String> _readData(String filename) async {
    try {
      final file = await _getFile(filename);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      // Log error silently, return empty string
      print('Error reading $filename: $e');
    }
    return '';
  }

  Future<void> _writeData(String filename, String data) async {
    try {
      final file = await _getFile(filename);
      await file.writeAsString(data);
    } catch (e) {
      print('Error writing $filename: $e');
    }
  }

  // Saved Articles
  Future<List<Article>> loadSavedArticles() async {
    final data = await _readData('saved_articles.json');
    if (data.isEmpty) return [];
    try {
      final List decoded = json.decode(data);
      return decoded.map((item) => Article.fromJson(item)).toList();
    } catch (e) {
      print('Error decoding saved_articles: $e');
      return [];
    }
  }

  Future<void> saveSavedArticles(List<Article> articles) async {
    final data = json.encode(articles.map((a) => a.toJson()).toList());
    await _writeData('saved_articles.json', data);
  }

  // Collections
  Future<List<Collection>> loadCollections() async {
    final data = await _readData('collections.json');
    if (data.isEmpty) return _createDefaultCollections();
    try {
      final List decoded = json.decode(data);
      return decoded.map((item) => Collection.fromJson(item)).toList();
    } catch (e) {
      print('Error decoding collections: $e');
      return _createDefaultCollections();
    }
  }

  List<Collection> _createDefaultCollections() {
    return [
      Collection(id: 'col_default_opinion', name: 'Must Reads', color: 0xFF4A90E2, articleIds: [], tags: ['opinion']),
      Collection(id: 'col_default_politics', name: 'Politics', color: 0xFFF5A623, articleIds: [], tags: ['politics']),
      Collection(id: 'col_default_economics', name: 'Economics', color: 0xFF7ED321, articleIds: [], tags: ['economics']),
    ];
  }

  Future<void> saveCollections(List<Collection> collections) async {
    final data = json.encode(collections.map((c) => c.toJson()).toList());
    await _writeData('collections.json', data);
  }

  // Highlights
  Future<List<Highlight>> loadHighlights() async {
    final data = await _readData('highlights.json');
    if (data.isEmpty) return [];
    try {
      final List decoded = json.decode(data);
      return decoded.map((item) => Highlight.fromJson(item)).toList();
    } catch (e) {
      print('Error decoding highlights: $e');
      return [];
    }
  }

  Future<void> saveHighlights(List<Highlight> highlights) async {
    final data = json.encode(highlights.map((h) => h.toJson()).toList());
    await _writeData('highlights.json', data);
  }

  // User Profile
  Future<UserProfile> loadUserProfile() async {
    final data = await _readData('user_profile.json');
    if (data.isEmpty) return UserProfile();
    try {
      final decoded = json.decode(data);
      return UserProfile.fromJson(decoded);
    } catch (e) {
      print('Error decoding user_profile: $e');
      return UserProfile();
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final data = json.encode(profile.toJson());
    await _writeData('user_profile.json', data);
  }
}
