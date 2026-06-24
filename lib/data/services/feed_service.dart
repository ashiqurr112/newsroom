import 'dart:convert';
import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;
import '../models/article.dart';

class FeedService {
  final http.Client _client;

  FeedService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Article>> fetchFeed(String sourceName, String url, String region) async {
    try {
      final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return parseFeed(sourceName, response.body, region);
      } else {
        print('Error fetching $sourceName: status code ${response.statusCode}');
      }
    } catch (e) {
      print('Exception fetching $sourceName: $e');
    }
    return [];
  }

  List<Article> parseFeed(String sourceName, String xmlContent, String region) {
    final List<Article> articles = [];
    try {
      final document = XmlDocument.parse(xmlContent);
      
      // Try RSS 2.0
      final items = document.findAllElements('item');
      if (items.isNotEmpty) {
        for (final item in items) {
          try {
            final titleElements = item.findElements('title');
            final title = titleElements.isEmpty ? 'Untitled' : titleElements.first.innerText.trim();
            
            final linkElements = item.findElements('link');
            final link = linkElements.isEmpty ? '' : linkElements.first.innerText.trim();
            if (link.isEmpty) continue;
            
            final descElements = item.findElements('description');
            final description = descElements.isEmpty ? '' : descElements.first.innerText.trim();
            final snippet = _stripHtml(description);
            
            final pubDateElements = item.findElements('pubDate');
            final pubDateStr = pubDateElements.isEmpty ? '' : pubDateElements.first.innerText.trim();
            final pubDate = _parseDate(pubDateStr);
            
            // Extract author: check dc:creator, author, or creator
            String author = 'Staff Writer';
            final creatorElements = item.findElements('dc:creator');
            final authorElements = item.findElements('author');
            final cElements = item.findElements('creator');
            
            String creator = '';
            if (creatorElements.isNotEmpty) {
              creator = creatorElements.first.innerText.trim();
            } else if (authorElements.isNotEmpty) {
              creator = authorElements.first.innerText.trim();
            } else if (cElements.isNotEmpty) {
              creator = cElements.first.innerText.trim();
            }
            
            if (creator.isNotEmpty) {
              // Strip email addresses or formatting like "by name"
              if (creator.toLowerCase().startsWith('by ')) {
                creator = creator.substring(3);
              }
              author = creator;
            }
            
            // Calculate reading time
            final words = snippet.split(RegExp(r'\s+')).length;
            final readTime = (words / 200).ceil(); // ~200 WPM
            final estimatedReadingTime = readTime > 0 ? readTime : 1;

            final id = _generateId(link);

            articles.add(Article(
              id: id,
              title: title,
              link: link,
              description: description,
              contentSnippet: snippet,
              pubDate: pubDate,
              author: author,
              source: sourceName,
              estimatedReadingTime: estimatedReadingTime,
              region: region,
            ));
          } catch (e) {
            print('Error parsing RSS item for $sourceName: $e');
          }
        }
      } else {
        // Try Atom feed
        final entries = document.findAllElements('entry');
        for (final entry in entries) {
          try {
            final titleElements = entry.findElements('title');
            final title = titleElements.isEmpty ? 'Untitled' : titleElements.first.innerText.trim();
            
            String link = '';
            final linkElements = entry.findElements('link');
            if (linkElements.isNotEmpty) {
              link = linkElements.first.getAttribute('href')?.trim() ?? '';
            }
            if (link.isEmpty) continue;
            
            final contentElements = entry.findElements('content');
            final summaryElements = entry.findElements('summary');
            final description = contentElements.isNotEmpty 
                ? contentElements.first.innerText.trim() 
                : (summaryElements.isNotEmpty ? summaryElements.first.innerText.trim() : '');
            final snippet = _stripHtml(description);
            
            final publishedElements = entry.findElements('published');
            final updatedElements = entry.findElements('updated');
            final pubDateStr = publishedElements.isNotEmpty 
                ? publishedElements.first.innerText.trim() 
                : (updatedElements.isNotEmpty ? updatedElements.first.innerText.trim() : '');
            final pubDate = _parseDate(pubDateStr);
            
            String author = 'Staff Writer';
            final authorNodeElements = entry.findElements('author');
            if (authorNodeElements.isNotEmpty) {
              final authorNode = authorNodeElements.first;
              final nameElements = authorNode.findElements('name');
              final authorName = nameElements.isEmpty ? '' : nameElements.first.innerText.trim();
              if (authorName.isNotEmpty) {
                author = authorName;
              }
            }
            
            final words = snippet.split(RegExp(r'\s+')).length;
            final readTime = (words / 200).ceil();
            final estimatedReadingTime = readTime > 0 ? readTime : 1;

            final id = _generateId(link);

            articles.add(Article(
              id: id,
              title: title,
              link: link,
              description: description,
              contentSnippet: snippet,
              pubDate: pubDate,
              author: author,
              source: sourceName,
              estimatedReadingTime: estimatedReadingTime,
              region: region,
            ));
          } catch (e) {
            print('Error parsing Atom entry for $sourceName: $e');
          }
        }
      }
    } catch (e) {
      print('Error parsing XML for $sourceName: $e');
    }
    return articles;
  }

  String _stripHtml(String htmlString) {
    if (htmlString.isEmpty) return '';
    // Strip script and style tags and their contents
    var clean = htmlString.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?<\/script>', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false), '');
    // Strip HTML tags
    clean = clean.replaceAll(RegExp(r'<[^>]*>'), ' ');
    // Decode common entities
    clean = clean
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    // Remove extra whitespace
    return clean.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  DateTime _parseDate(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now();
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      try {
        return _parseRfc822(dateStr);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  DateTime _parseRfc822(String dateStr) {
    try {
      var cleaned = dateStr;
      if (cleaned.contains(',')) {
        cleaned = cleaned.substring(cleaned.indexOf(',') + 1).trim();
      }
      
      final parts = cleaned.split(RegExp(r'\s+'));
      if (parts.length < 3) return DateTime.now();
      
      final day = int.parse(parts[0]);
      final monthStr = parts[1].toLowerCase();
      final year = int.parse(parts[2]);
      
      final months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
      };
      final month = months[monthStr.substring(0, 3)] ?? 1;
      
      int hour = 0, minute = 0, second = 0;
      if (parts.length > 3) {
        final timeParts = parts[3].split(':');
        if (timeParts.length >= 2) {
          hour = int.parse(timeParts[0]);
          minute = int.parse(timeParts[1]);
        }
        if (timeParts.length >= 3) {
          second = int.parse(timeParts[2]);
        }
      }
      
      return DateTime.utc(year, month, day, hour, minute, second);
    } catch (_) {
      return DateTime.now();
    }
  }

  String _generateId(String link) {
    return link.hashCode.toString();
  }
}
