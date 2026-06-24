import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:newsroom/data/models/article.dart';
import 'package:newsroom/ui/features/profile/view_models/user_view_model.dart';
import 'package:newsroom/ui/features/feed/view_models/feed_view_model.dart';
import 'package:newsroom/ui/features/reader/views/reader_view.dart';

class DiscoveryView extends StatelessWidget {
  const DiscoveryView({super.key});

  // Curated prominent topics and keywords for grouping
  static const Map<String, List<String>> _curatedTopics = {
    'AI & Technology': ['ai', 'artificial intelligence', 'tech', 'algorithm', 'silicon valley', 'chatgpt'],
    'Climate & Environment': ['climate', 'warming', 'carbon', 'greenhouse', 'renewable', 'emissions', 'pollution'],
    'Economic Policy': ['inflation', 'interest rates', 'tax', 'recession', 'economy', 'budget', 'federal reserve', 'debt'],
    'Global Geopolitics': ['china', 'russia', 'war', 'ukraine', 'geopolitical', 'middle east', 'trade war', 'nato'],
    'Democracy & Elections': ['election', 'vote', 'democratic', 'poll', 'campaign', 'biden', 'trump', 'parliament'],
  };

  // Group outlets by general editorial stance to pair contrasting views
  static const List<String> _groupA = ['The Wall Street Journal', 'The Times', 'The Economist']; // Generally center-right/libertarian/conservative leaning
  static const List<String> _groupB = ['The Guardian', 'The New York Times', 'Al Jazeera', 'The Independent', 'The Conversation']; // Generally center-left/liberal/progressive leaning

  @override
  Widget build(BuildContext context) {
    final feedVM = Provider.of<FeedViewModel>(context);
    final userVM = Provider.of<UserViewModel>(context);
    final theme = Theme.of(context);

    // Get all downloaded articles
    final allArticles = feedVM.articles;

    // 1. Topic of the Week groupings
    final Map<String, List<Article>> topicGroupings = {};
    _curatedTopics.forEach((topicName, keywords) {
      final matches = allArticles.where((article) {
        final title = article.title.toLowerCase();
        final desc = article.contentSnippet.toLowerCase();
        return keywords.any((kw) => title.contains(kw) || desc.contains(kw));
      }).toList();
      if (matches.isNotEmpty) {
        topicGroupings[topicName] = matches;
      }
    });

    // 2. Contrasting Views pairings
    final List<Map<String, Article>> contrastingPairs = [];
    _curatedTopics.forEach((topicName, keywords) {
      final articlesA = allArticles.where((art) {
        final title = art.title.toLowerCase();
        final desc = art.contentSnippet.toLowerCase();
        final matchesKw = keywords.any((kw) => title.contains(kw) || desc.contains(kw));
        return matchesKw && _groupA.contains(art.source);
      }).toList();

      final articlesB = allArticles.where((art) {
        final title = art.title.toLowerCase();
        final desc = art.contentSnippet.toLowerCase();
        final matchesKw = keywords.any((kw) => title.contains(kw) || desc.contains(kw));
        return matchesKw && _groupB.contains(art.source);
      }).toList();

      if (articlesA.isNotEmpty && articlesB.isNotEmpty) {
        contrastingPairs.add({
          'Topic': Article(
            id: topicName,
            title: topicName, // We reuse model or just pass key values
            link: '', description: '', contentSnippet: '', pubDate: DateTime.now(), author: '', source: '', estimatedReadingTime: 0, region: '',
          ),
          'Left': articlesB.first,
          'Right': articlesA.first,
        });
      }
    });

    // 3. Followed Authors articles
    final followedAuthorArticles = allArticles.where((art) {
      return userVM.profile.followedAuthors.any((auth) => art.author.toLowerCase().contains(auth.toLowerCase()));
    }).toList();

    // 4. Recommend popular authors in current feed (who aren't followed yet)
    final Map<String, int> authorCounts = {};
    for (var art in allArticles) {
      if (art.author.isNotEmpty && art.author != 'Staff Writer' && art.author != 'Staff') {
        authorCounts[art.author] = (authorCounts[art.author] ?? 0) + 1;
      }
    }
    final sortedAuthors = authorCounts.keys.where((auth) {
      return !userVM.profile.followedAuthors.any((followed) => auth.toLowerCase().contains(followed.toLowerCase()));
    }).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Discovery', style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Topics'),
              Tab(text: 'Contrasting Views'),
              Tab(text: 'Authors'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- TOPICS TAB ---
            topicGroupings.isEmpty
                ? const Center(child: Text('No topics parsed yet. Pull to refresh feed on the main tab.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: topicGroupings.length,
                    itemBuilder: (context, index) {
                      final topicName = topicGroupings.keys.elementAt(index);
                      final matches = topicGroupings[topicName]!;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ExpansionTile(
                          title: Text(topicName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text('${matches.length} editorials covering this event'),
                          leading: CircleAvatar(
                            backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                            child: Icon(Icons.explore_rounded, color: theme.primaryColor),
                          ),
                          children: matches.map((article) {
                            return ListTile(
                              title: Text(article.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              subtitle: Text('${article.source} • By ${article.author}'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ReaderView(article: article)),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),

            // --- CONTRASTING VIEWS TAB ---
            contrastingPairs.isEmpty
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('Pairing editorials... Run refresh on main feed to load views from multiple sources.', textAlign: TextAlign.center),
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: contrastingPairs.length,
                    itemBuilder: (context, index) {
                      final pair = contrastingPairs[index];
                      final topic = pair['Topic']!.id; // Topic name stored here
                      final leftArt = pair['Left']!;
                      final rightArt = pair['Right']!;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Contrasting: $topic',
                                style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left View Card
                                Expanded(
                                  child: InkWell(
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ReaderView(article: leftArt))),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(leftArt.source, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue)),
                                        const SizedBox(height: 4),
                                        Text(leftArt.title, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
                                        const SizedBox(height: 4),
                                        Text('By ${leftArt.author}', style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(width: 1, height: 120, color: theme.dividerColor),
                                const SizedBox(width: 16),
                                // Right View Card
                                Expanded(
                                  child: InkWell(
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ReaderView(article: rightArt))),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(rightArt.source, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red)),
                                        const SizedBox(height: 4),
                                        Text(rightArt.title, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
                                        const SizedBox(height: 4),
                                        Text('By ${rightArt.author}', style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

            // --- AUTHORS TAB ---
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Followed Columnists Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Followed Columnists', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      onPressed: () => _showAddAuthorDialog(context, userVM),
                      tooltip: 'Follow specific author',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (userVM.profile.followedAuthors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text(
                        'You are not following any columnists yet.',
                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    children: userVM.profile.followedAuthors.map((auth) {
                      return Chip(
                        avatar: const CircleAvatar(child: Icon(Icons.person, size: 14)),
                        label: Text(auth),
                        onDeleted: () => userVM.unfollowAuthor(auth),
                      );
                    }).toList(),
                  ),
                const Divider(height: 32),

                // Latest from Followed Columnists
                if (followedAuthorArticles.isNotEmpty) ...[
                  const Text('Latest Articles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...followedAuthorArticles.map((art) {
                    return Card(
                      child: ListTile(
                        title: Text(art.title),
                        subtitle: Text('${art.source} • By ${art.author}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ReaderView(article: art))),
                      ),
                    );
                  }),
                  const Divider(height: 32),
                ],

                // Recommended Authors to follow
                if (sortedAuthors.isNotEmpty) ...[
                  const Text('Suggested Columnists', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedAuthors.length > 5 ? 5 : sortedAuthors.length,
                    itemBuilder: (context, index) {
                      final author = sortedAuthors[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                        title: Text(author),
                        subtitle: const Text('Columnist in active feed'),
                        trailing: TextButton.icon(
                          onPressed: () => userVM.followAuthor(author),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Follow'),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAuthorDialog(BuildContext context, UserViewModel userVM) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Follow Columnist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter columnist full name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  userVM.followAuthor(controller.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('Follow'),
            ),
          ],
        );
      },
    );
  }
}
