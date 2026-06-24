import 'dart:convert';
import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import '../models/article.dart';

class FullArticleContent {
  final List<String> paragraphs;
  final String? imageUrl;

  FullArticleContent({required this.paragraphs, this.imageUrl});
}

class FeedService {
  final http.Client _client;

  FeedService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Article>> fetchFeed(String sourceName, String url, String region) async {
    try {
      final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        return parseFeed(sourceName, decodedBody, region);
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

            // Image extraction for RSS
            String? imageUrl;
            final mediaContent = item.findElements('media:content');
            final enclosure = item.findElements('enclosure');
            final mediaThumbnail = item.findElements('media:thumbnail');
            
            if (mediaContent.isNotEmpty) {
              imageUrl = mediaContent.first.getAttribute('url');
            } else if (enclosure.isNotEmpty) {
              imageUrl = enclosure.first.getAttribute('url');
            } else if (mediaThumbnail.isNotEmpty) {
              imageUrl = mediaThumbnail.first.getAttribute('url');
            }
            
            if (imageUrl == null && description.isNotEmpty) {
              final match = RegExp(r'''<img[^>]+src=["']([^"']+)["']''', caseSensitive: false).firstMatch(description);
              if (match != null) {
                imageUrl = match.group(1);
              }
            }

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
              imageUrl: imageUrl,
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

            // Image extraction for Atom
            String? imageUrl;
            final mediaContent = entry.findElements('media:content');
            final mediaThumbnail = entry.findElements('media:thumbnail');
            
            XmlElement? linkImage;
            try {
              final linkImages = entry.findElements('link').where(
                (e) => e.getAttribute('rel') == 'enclosure' && (e.getAttribute('type')?.startsWith('image/') ?? false),
              );
              if (linkImages.isNotEmpty) {
                linkImage = linkImages.first;
              }
            } catch (_) {
              // Ignore
            }
            
            if (mediaContent.isNotEmpty) {
              imageUrl = mediaContent.first.getAttribute('url');
            } else if (mediaThumbnail.isNotEmpty) {
              imageUrl = mediaThumbnail.first.getAttribute('url');
            } else if (linkImage != null) {
              imageUrl = linkImage.getAttribute('href');
            }
            
            if (imageUrl == null && description.isNotEmpty) {
              final match = RegExp(r'''<img[^>]+src=["']([^"']+)["']''', caseSensitive: false).firstMatch(description);
              if (match != null) {
                imageUrl = match.group(1);
              }
            }

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
              imageUrl: imageUrl,
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

  Future<FullArticleContent> fetchFullArticle(String source, String url) async {
    final Map<String, String> headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
    };

    if (source == 'The New York Times') {
      headers['User-Agent'] = 'Mozilla/5.0 (compatible; Google-InspectionTool/1.0)';
    } else if (source == 'The Wall Street Journal') {
      headers['Referer'] = 'https://www.drudgereport.com/';
      headers['User-Agent'] = 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';
    } else if (source == 'Financial Times') {
      headers['Referer'] = 'https://www.google.com/';
      headers['User-Agent'] = 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';
    } else if (source == 'The Economist') {
      headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.6533.103 Mobile Safari/537.36 Liskov';
    } else if (source == 'Project Syndicate') {
      headers['User-Agent'] = 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';
      headers['Referer'] = 'https://www.google.com/';
      headers['X-Forwarded-For'] = '66.249.66.1';
    }

    // Tier 1: Direct Request
    try {
      final response = await _client.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        final content = extractParagraphsAndImage(decodedBody, source);
        if (content.paragraphs.length >= 3) {
          return content;
        }
      }
    } catch (e) {
      print('Exception fetching direct full article: $e');
    }

    // Tier 2: Txtify Proxy
    try {
      final txtifyUrl = 'https://txtify.it/$url';
      final response = await _client.get(Uri.parse(txtifyUrl)).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        final content = extractParagraphsAndImage(decodedBody, source);
        if (content.paragraphs.length >= 3) {
          return content;
        }
      }
    } catch (e) {
      print('Exception fetching via Txtify: $e');
    }

    // Tier 3: Google Web Cache
    try {
      final cacheUrl = 'https://webcache.googleusercontent.com/search?q=cache:$url';
      final response = await _client.get(Uri.parse(cacheUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        final content = extractParagraphsAndImage(decodedBody, source);
        if (content.paragraphs.length >= 3) {
          return content;
        }
      }
    } catch (e) {
      print('Exception fetching via Google Web Cache: $e');
    }

    // Tier 4: Wayback Machine
    try {
      final waybackApiUrl = 'https://archive.org/wayback/available?url=${Uri.encodeComponent(url)}';
      final waybackResponse = await _client.get(Uri.parse(waybackApiUrl)).timeout(const Duration(seconds: 8));
      if (waybackResponse.statusCode == 200) {
        final data = json.decode(waybackResponse.body) as Map<String, dynamic>;
        final closest = data['archived_snapshots']?['closest'];
        if (closest != null && closest['available'] == true) {
          final snapshotUrl = closest['url'] as String;
          // Rewrite snapshot URL to get raw HTML (without toolbar)
          final rawSnapshotUrl = snapshotUrl.replaceFirst(RegExp(r'/web/(\d+)/'), '/web/\$1id_/');
          
          final rawResponse = await _client.get(Uri.parse(rawSnapshotUrl)).timeout(const Duration(seconds: 12));
          if (rawResponse.statusCode == 200) {
            final decodedBody = utf8.decode(rawResponse.bodyBytes, allowMalformed: true);
            final content = extractParagraphsAndImage(decodedBody, source);
            if (content.paragraphs.length >= 3) {
              return content;
            }
          }
        }
      }
    } catch (e) {
      print('Exception fetching via Wayback Machine: $e');
    }
    
    return FullArticleContent(paragraphs: [], imageUrl: null); // Return empty if all fail
  }

  FullArticleContent extractParagraphsAndImage(String htmlString, String source) {
    final document = parse(htmlString);
    
    // Extract og:image
    String? imageUrl;
    final ogImageMeta = document.querySelector('head > meta[property="og:image"]');
    if (ogImageMeta != null) {
      imageUrl = ogImageMeta.attributes['content'];
    }
    if (imageUrl == null) {
      final twitterImageMeta = document.querySelector('head > meta[name="twitter:image"]');
      if (twitterImageMeta != null) {
        imageUrl = twitterImageMeta.attributes['content'];
      }
    }

    List<Element> pElements = [];
    
    if (source == 'The New York Times') {
      pElements = document.querySelectorAll('section[name="articleBody"] p, div.StoryBodyCompanionColumn p, .story-body-text p');
    } else if (source == 'The Wall Street Journal') {
      pElements = document.querySelectorAll('article section p, div.wsj-snippet-body p');
    } else if (source == 'Financial Times') {
      pElements = document.querySelectorAll('div[class*="article-body"] p, div.n-layout__row--content p');
    } else if (source == 'The Economist') {
      pElements = document.querySelectorAll('article p, div[class*="article__body"] p');
    } else if (source == 'The Independent') {
      pElements = document.querySelectorAll('div#main p, div.body-content p, div[class*="body-wrap"] p');
    } else if (source == 'The Guardian') {
      pElements = document.querySelectorAll('div[data-gutter] p, div[class*="article-body"] p, div.story-body p');
    } else if (source == 'BBC') {
      pElements = document.querySelectorAll('article p, div[class*="RichTextContainer"] p');
    } else if (source == 'The Conversation') {
      pElements = document.querySelectorAll('div[itemprop="articleBody"] p, div.entry-content p');
    }
    
    // Fallbacks
    if (pElements.isEmpty) {
      pElements = document.querySelectorAll('article p');
    }
    if (pElements.isEmpty) {
      pElements = document.querySelectorAll('main p');
    }
    if (pElements.isEmpty) {
      pElements = document.querySelectorAll('div[class*="article"] p, div[class*="body"] p');
    }
    if (pElements.isEmpty) {
      pElements = document.querySelectorAll('p');
    }

    final List<String> paragraphs = [];
    for (final elem in pElements) {
      final text = elem.text.trim();
      if (text.isEmpty) continue;
      
      // Filter out common ads, share prompts, navigation items, cookie notices
      if (text.length < 15 && (text.toLowerCase().contains('share') || text.toLowerCase().contains('follow') || text.toLowerCase().contains('ad'))) {
        continue;
      }
      if (text.startsWith('Copyright ') || text.startsWith('© ')) {
        continue;
      }
      
      paragraphs.add(text);
    }
    
    return FullArticleContent(paragraphs: paragraphs, imageUrl: imageUrl);
  }

  List<String> extractParagraphs(String htmlString, String source) {
    return extractParagraphsAndImage(htmlString, source).paragraphs;
  }
}
