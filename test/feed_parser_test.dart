import 'package:flutter_test/flutter_test.dart';
import 'package:newsroom/data/services/feed_service.dart';

void main() {
  group('FeedService XML Parsing Tests', () {
    final feedService = FeedService();

    test('Parses RSS 2.0 Opinion Feed successfully', () {
      const rssContent = '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>NYT Opinion</title>
    <link>https://www.nytimes.com/section/opinion</link>
    <description>Opinion pieces</description>
    <item>
      <title>The Future of AI</title>
      <link>https://www.nytimes.com/ai-future</link>
      <description>&lt;p&gt;Artificial intelligence is evolving rapidly. &lt;b&gt;Here is what it means.&lt;/b&gt;&lt;/p&gt;</description>
      <dc:creator>John Doe</dc:creator>
      <pubDate>Wed, 24 Jun 2026 12:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';

      final articles = feedService.parseFeed('The New York Times', rssContent, 'US');

      expect(articles.length, 1);
      expect(articles[0].title, 'The Future of AI');
      expect(articles[0].link, 'https://www.nytimes.com/ai-future');
      expect(articles[0].author, 'John Doe');
      expect(articles[0].contentSnippet, 'Artificial intelligence is evolving rapidly. Here is what it means.');
      expect(articles[0].source, 'The New York Times');
      expect(articles[0].region, 'US');
    });

    test('Parses Atom Feed successfully', () {
      const atomContent = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Guardian Opinion</title>
  <entry>
    <title>Climate Action Now</title>
    <link href="https://www.theguardian.com/climate"/>
    <summary>We must take action against carbon emissions.</summary>
    <author>
      <name>Jane Smith</name>
    </author>
    <published>2026-06-24T12:00:00Z</published>
  </entry>
</feed>''';

      final articles = feedService.parseFeed('The Guardian', atomContent, 'Europe');

      expect(articles.length, 1);
      expect(articles[0].title, 'Climate Action Now');
      expect(articles[0].link, 'https://www.theguardian.com/climate');
      expect(articles[0].author, 'Jane Smith');
      expect(articles[0].contentSnippet, 'We must take action against carbon emissions.');
      expect(articles[0].region, 'Europe');
    });

    test('Strips HTML and decodes entities correctly', () {
      const rssContent = '''<rss version="2.0">
  <channel>
    <item>
      <title>Test</title>
      <link>https://test.com</link>
      <description>&lt;p&gt;Hello &amp;amp; welcome to the &amp;lt;reading mode&amp;gt;.&lt;/p&gt;</description>
      <pubDate>Wed, 24 Jun 2026 12:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';

      final articles = feedService.parseFeed('Test Source', rssContent, 'Global');
      expect(articles[0].contentSnippet, 'Hello & welcome to the <reading mode>.');
    });

    test('Calculates reading time correctly', () {
      final words = List.generate(410, (_) => 'word').join(' ');
      const rssContent = '''<rss version="2.0">
  <channel>
    <item>
      <title>Test</title>
      <link>https://test.com</link>
      <description>#desc</description>
      <pubDate>Wed, 24 Jun 2026 12:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';

      final withWords = rssContent.replaceAll('#desc', words);
      final articles = feedService.parseFeed('Test Source', withWords, 'Global');
      expect(articles[0].estimatedReadingTime, 3); // Ceil(410/200) = 3
    });
  });
}
