import 'package:flutter_test/flutter_test.dart';
import 'package:newsroom/data/services/feed_service.dart';

void main() {
  group('FeedService XML Parsing Tests', () {
    final feedService = FeedService();

    test('Parses RSS 2.0 Opinion Feed successfully', () {
      const rssContent = '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:media="http://search.yahoo.com/mrss/">
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
      <media:content url="https://images.com/ai-future.jpg" />
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
      expect(articles[0].imageUrl, 'https://images.com/ai-future.jpg');
    });

    test('Parses Atom Feed successfully', () {
      const atomContent = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Guardian Opinion</title>
  <entry>
    <title>Climate Action Now</title>
    <link href="https://www.theguardian.com/climate"/>
    <link rel="enclosure" type="image/jpeg" href="https://images.com/climate.jpg"/>
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
      expect(articles[0].imageUrl, 'https://images.com/climate.jpg');
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

    test('Extracts Project Syndicate article body and excludes promotions/bios', () {
      const htmlContent = '''
<!DOCTYPE html>
<html>
<body>
  <div class="article__abs u-mt-se">
    <p>For a brief period after the Cold War, Americans persuaded themselves...</p>
  </div>
  <div class="article__body article__body--commentary english">
    <p>LONDON—This is the first actual paragraph of the article.</p>
    <aside class="inlay inlay--slide slide__container editorpick-container mrf mrf-editorpicks">
      <div class="article-card__excerpt">
        <p>This is a recommended article description that should be excluded.</p>
      </div>
    </aside>
    <p>This is the second actual paragraph of the article.</p>
    <div class="listing special inlay special--generic mrf mrf--promotion">
      <p>This is a registration promotion that should be excluded.</p>
    </div>
    <p>This is the third actual paragraph of the article.</p>
  </div>
  <div class="u-mb" data-id="some-author">
    <p>Author Biography paragraph that should be excluded because it is outside article__body.</p>
  </div>
</body>
</html>
''';

      final content = feedService.extractBodyContent(htmlContent, 'Project Syndicate');
      final textBlocks = content.where((b) => b.type == 'text').toList();

      expect(textBlocks.length, 4);
      expect(textBlocks[0].value, 'For a brief period after the Cold War, Americans persuaded themselves...');
      expect(textBlocks[1].value, 'LONDON—This is the first actual paragraph of the article.');
      expect(textBlocks[2].value, 'This is the second actual paragraph of the article.');
      expect(textBlocks[3].value, 'This is the third actual paragraph of the article.');
    });

    test('Extracts BBC article body and excludes promotions while retaining content within ContainerWithSidebarWrapper', () {
      const htmlContent = '''
<!DOCTYPE html>
<html>
<body>
  <div class="ssrcss-js09yk-ContainerWithSidebarWrapper">
    <article class="ssrcss-2fe4mx-ArticleWrapper">
      <div class="ssrcss-nqezkk-RichTextContainer">
        <p>This is the first paragraph of the BBC article.</p>
      </div>
      <figure class="ssrcss-hc6arm-StyledFigure">
        <img src="https://ichef.bbci.co.uk/image1.jpg" />
      </figure>
      <div class="ssrcss-nqezkk-RichTextContainer">
        <p>This is the second paragraph of the BBC article.</p>
        <div class="ssrcss-5gf2d0-PromoLink">
          <p>This is an inline related article promo that should be excluded.</p>
        </div>
      </div>
    </article>
  </div>
</body>
</html>
''';

      final content = feedService.extractBodyContent(htmlContent, 'BBC');
      
      expect(content.length, 3);
      expect(content[0].type, 'text');
      expect(content[0].value, 'This is the first paragraph of the BBC article.');
      expect(content[1].type, 'image');
      expect(content[1].value, 'https://ichef.bbci.co.uk/image1.jpg');
      expect(content[2].type, 'text');
      expect(content[2].value, 'This is the second paragraph of the BBC article.');
    });
  });
}
