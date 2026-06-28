import 'dart:convert';
import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import '../models/article.dart';

class FullArticleContent {
  final List<ArticleContentBlock> bodyContent;
  final String? imageUrl;

  FullArticleContent({required this.bodyContent, this.imageUrl});
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
        if (!isPaywalled(decodedBody, source)) {
          final content = extractBodyContentAndHeaderImage(decodedBody, source);
          final textBlocks = content.bodyContent.where((b) => b.type == 'text').toList();
          if (textBlocks.length >= 3) {
            return content;
          }
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
        if (!isPaywalled(decodedBody, source)) {
          final content = extractBodyContentAndHeaderImage(decodedBody, source);
          final textBlocks = content.bodyContent.where((b) => b.type == 'text').toList();
          if (textBlocks.length >= 3) {
            return content;
          }
        }
      }
    } catch (e) {
      print('Exception fetching via Txtify: $e');
    }

    // Tier 3: Archive.ph Fallback
    try {
      final archiveUrl = 'https://archive.ph/$url';
      final response = await _client.get(Uri.parse(archiveUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        if (!isPaywalled(decodedBody, source)) {
          final content = extractBodyContentAndHeaderImage(decodedBody, source);
          final textBlocks = content.bodyContent.where((b) => b.type == 'text').toList();
          if (textBlocks.length >= 3) {
            return content;
          }
        }
      }
    } catch (e) {
      print('Exception fetching via archive.ph: $e');
    }

    // Tier 4: Google Web Cache
    try {
      final cacheUrl = 'https://webcache.googleusercontent.com/search?q=cache:$url';
      final response = await _client.get(Uri.parse(cacheUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        if (!isPaywalled(decodedBody, source)) {
          final content = extractBodyContentAndHeaderImage(decodedBody, source);
          final textBlocks = content.bodyContent.where((b) => b.type == 'text').toList();
          if (textBlocks.length >= 3) {
            return content;
          }
        }
      }
    } catch (e) {
      print('Exception fetching via Google Web Cache: $e');
    }

    // Tier 5: Wayback Machine
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
            if (!isPaywalled(decodedBody, source)) {
              final content = extractBodyContentAndHeaderImage(decodedBody, source);
              final textBlocks = content.bodyContent.where((b) => b.type == 'text').toList();
              if (textBlocks.length >= 3) {
                return content;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Exception fetching via Wayback Machine: $e');
    }
    
    return FullArticleContent(bodyContent: [], imageUrl: null); // Return empty if all fail
  }

  bool isPaywalled(String html, String source) {
    final document = parse(html);
    if (source == 'Financial Times') {
      return document.querySelector('div#barrier-page') != null || html.contains('barrier-page');
    } else if (source == 'The New York Times') {
      return document.querySelector('div#gateway-content') != null || html.contains('gateway-content');
    }
    
    // Generic check for common paywall markers
    final paywallKeywords = ['paywall', 'subscription-gate', 'regwall', 'subscribe-to-read'];
    for (final kw in paywallKeywords) {
      if (html.contains(kw)) {
        if (document.querySelector('div[class*="paywall"], div[id*="paywall"], .subscription-barrier') != null) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isUnwantedBlock(Element element) {
    var current = element.parent;
    while (current != null) {
      final tag = current.localName?.toLowerCase();
      if (tag == 'aside' || tag == 'footer' || tag == 'header' || tag == 'nav' || tag == 'audio' || tag == 'video') {
        return true;
      }
      for (final cls in current.classes) {
        final c = cls.toLowerCase();
        if (c.contains('promo') ||
            c.contains('newsletter') ||
            c.contains('editorpick') ||
            c.contains('inlay') ||
            c.contains('social') ||
            c.contains('share') ||
            c.contains('byline') ||
            c.contains('author') ||
            c.contains('bio') ||
            (c.contains('sidebar') && !c.contains('wrapper') && !c.contains('container')) ||
            c.contains('widget') ||
            (c.contains('comment') && !c.contains('commentary')) ||
            c.contains('related')) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  List<ArticleContentBlock> extractBodyContent(String htmlString, String source) {
    final document = parse(htmlString);
    List<Element> containers = [];

    if (source == 'The New York Times') {
      containers = document.querySelectorAll('section[name="articleBody"], div.StoryBodyCompanionColumn, .story-body-text');
    } else if (source == 'Financial Times') {
      containers = document.querySelectorAll('div[class*="article-body"], div.n-layout__row--content');
    } else if (source == 'The Economist') {
      containers = document.querySelectorAll('article, div[class*="article__body"]');
    } else if (source == 'The Independent') {
      containers = document.querySelectorAll('div#main, div.body-content, div[class*="body-wrap"]');
    } else if (source == 'The Guardian') {
      containers = document.querySelectorAll('div[data-gutter], div[class*="article-body"], div.story-body');
    } else if (source == 'BBC') {
      containers = document.querySelectorAll('article, div[class*="RichTextContainer"]');
    } else if (source == 'The Conversation') {
      containers = document.querySelectorAll('div[itemprop="articleBody"], div.entry-content');
    } else if (source == 'Project Syndicate') {
      containers = document.querySelectorAll('div.article__abs, div.article__body');
    }

    if (containers.isEmpty) {
      containers = document.querySelectorAll('article');
    }
    if (containers.isEmpty) {
      containers = document.querySelectorAll('main');
    }
    if (containers.isEmpty) {
      containers = document.querySelectorAll('div[class*="article"], div[class*="body"]');
    }

    // Filter out containers that are descendants of other containers to prevent duplicate parsing
    final List<Element> uniqueContainers = [];
    for (final c in containers) {
      if (!uniqueContainers.any((parent) => parent.contains(c))) {
        uniqueContainers.add(c);
      }
    }

    final List<ArticleContentBlock> blocks = [];
    final Set<String> processedTexts = {};
    final Set<String> processedImages = {};

    String? getActualSrc(Element img) {
      final attrs = img.attributes;
      final candidates = ['src', 'data-src', 'data-srcset', 'srcset', 'currentsourceurl', 'data-urllink'];
      for (final key in candidates) {
        final val = attrs[key]?.trim();
        if (val != null && val.isNotEmpty && !val.startsWith('data:image/')) {
          if (key == 'srcset' || key == 'data-srcset') {
            final parts = val.split(',');
            if (parts.isNotEmpty) {
              final firstUrl = parts.first.trim().split(' ').first;
              if (firstUrl.isNotEmpty) return firstUrl;
            }
          } else {
            return val;
          }
        }
      }
      return attrs['src']?.trim();
    }

    void traverse(Element element) {
      final elements = element.querySelectorAll('p, img');
      for (final elem in elements) {
        if (_isUnwantedBlock(elem)) continue;
        if (elem.localName == 'p') {
          final text = elem.text.trim();
          if (text.isEmpty) continue;
          if (text.length < 15 && (text.toLowerCase().contains('share') || text.toLowerCase().contains('follow') || text.toLowerCase().contains('ad'))) {
            continue;
          }
          if (text.startsWith('Copyright ') || text.startsWith('© ')) {
            continue;
          }
          if (!processedTexts.contains(text)) {
            processedTexts.add(text);
            blocks.add(ArticleContentBlock(type: 'text', value: text));
          }
        } else if (elem.localName == 'img') {
          final src = getActualSrc(elem);
          if (src != null && src.isNotEmpty && !src.startsWith('data:image/')) {
            var fullSrc = src;
            if (src.startsWith('//')) {
              fullSrc = 'https:$src';
            }
            if (!processedImages.contains(fullSrc)) {
              processedImages.add(fullSrc);
              blocks.add(ArticleContentBlock(type: 'image', value: fullSrc));
            }
          }
        }
      }
    }

    if (uniqueContainers.isNotEmpty) {
      for (final container in uniqueContainers) {
        traverse(container);
      }
    } else {
      final body = document.body;
      if (body != null) {
        traverse(body);
      }
    }

    return blocks;
  }

  FullArticleContent extractBodyContentAndHeaderImage(String htmlString, String source) {
    final document = parse(htmlString);
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

    final bodyContent = extractBodyContent(htmlString, source);

    if (imageUrl == null || imageUrl.isEmpty) {
      for (final block in bodyContent) {
        if (block.type == 'image') {
          imageUrl = block.value;
          break;
        }
      }
    } else {
      // Prevent duplicate rendering of the header image at the beginning of the body blocks
      bodyContent.removeWhere((block) {
        if (block.type == 'image') {
          final imgUrl = block.value;
          if (imgUrl == imageUrl) return true;
          try {
            final uri1 = Uri.parse(imageUrl!);
            final uri2 = Uri.parse(imgUrl);
            if (uri1.pathSegments.isNotEmpty && uri2.pathSegments.isNotEmpty) {
              if (uri1.pathSegments.last == uri2.pathSegments.last) {
                return true;
              }
            }
          } catch (_) {}
        }
        return false;
      });
    }

    return FullArticleContent(bodyContent: bodyContent, imageUrl: imageUrl);
  }
}

