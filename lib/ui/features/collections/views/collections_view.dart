import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:newsroom/data/models/article.dart';
import 'package:newsroom/data/models/collection.dart';
import 'package:newsroom/ui/features/profile/view_models/user_view_model.dart';
import 'package:newsroom/ui/features/reader/views/reader_view.dart';

class CollectionsView extends StatefulWidget {
  const CollectionsView({super.key});

  @override
  State<CollectionsView> createState() => _CollectionsViewState();
}

class _CollectionsViewState extends State<CollectionsView> {
  String _selectedTag = 'All';

  // Available colors for collection customisation
  static const List<int> _availableColors = [
    0xFF4A90E2, // Blue
    0xFFF5A623, // Orange
    0xFF7ED321, // Green
    0xFFBD10E0, // Purple
    0xFFD0021B, // Red
    0xFF50E3C2, // Teal
    0xFF4A4A4A, // Dark Gray
    0xFF9B9B9B, // Light Gray
  ];

  @override
  Widget build(BuildContext context) {
    final userVM = Provider.of<UserViewModel>(context);

    // Active saved articles (excluding archived ones)
    final savedArticles = userVM.savedArticles.where((a) => a.isSaved && !a.isArchived).toList();
    final archivedArticles = userVM.savedArticles.where((a) => a.isSaved && a.isArchived).toList();

    // Extract all unique tags
    final Set<String> allTags = {'All'};
    for (var col in userVM.collections) {
      allTags.addAll(col.tags);
    }
    // Simple filter by tags on the active saved articles
    final filteredArticles = _selectedTag == 'All'
        ? savedArticles
        : savedArticles.where((a) {
            // Find if this article belongs to a collection that has this tag
            return userVM.collections.any((col) => col.tags.contains(_selectedTag) && col.articleIds.contains(a.id));
          }).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Collections', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              icon: const Icon(Icons.create_new_folder_rounded),
              tooltip: 'New Collection',
              onPressed: () => _showCreateCollectionDialog(context, userVM),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Folders'),
              Tab(text: 'All Bookmarks'),
              Tab(text: 'Archive'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- TAB 1: FOLDERS (COLLECTIONS) ---
            userVM.collections.isEmpty
                ? const Center(child: Text('Create a folder to group your saved articles.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: userVM.collections.length,
                    itemBuilder: (context, index) {
                      final col = userVM.collections[index];
                      return Card(
                        color: Color(col.color).withValues(alpha: 0.12),
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Color(col.color).withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CollectionDetailsView(collection: col),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.folder_rounded, color: Color(col.color), size: 36),
                                const Spacer(),
                                Text(
                                  col.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${col.articleIds.length} articles',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

            // --- TAB 2: ALL SAVED BOOKMARKS WITH TAG FILTER ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag chips row
                if (allTags.length > 1)
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: allTags.map((tag) {
                        final isSelected = _selectedTag == tag;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(tag),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedTag = tag;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                Expanded(
                  child: filteredArticles.isEmpty
                      ? const Center(child: Text('No saved articles found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredArticles.length,
                          itemBuilder: (context, index) {
                            final art = filteredArticles[index];
                            return _articleListItem(context, art, userVM);
                          },
                        ),
                ),
              ],
            ),

            // --- TAB 3: ARCHIVE ---
            archivedArticles.isEmpty
                ? const Center(child: Text('Archive is empty. Saved articles older than 30 days are automatically archived.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: archivedArticles.length,
                    itemBuilder: (context, index) {
                      final art = archivedArticles[index];
                      return _articleListItem(context, art, userVM, isArchiveItem: true);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _articleListItem(BuildContext context, Article art, UserViewModel userVM, {bool isArchiveItem = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(art.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${art.source} • By ${art.author}'),
        trailing: isArchiveItem 
          ? const Icon(Icons.archive_outlined, color: Colors.grey)
          : IconButton(
              icon: const Icon(Icons.bookmark_remove_rounded, color: Colors.redAccent),
              onPressed: () => userVM.unsaveArticle(art.id),
              tooltip: 'Unsave Article',
            ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ReaderView(article: art)),
          );
        },
      ),
    );
  }

  void _showCreateCollectionDialog(BuildContext context, UserViewModel userVM) {
    final nameController = TextEditingController();
    final tagController = TextEditingController();
    int selectedColor = _availableColors[0];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('New Folder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(hintText: 'Folder Name'),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: tagController,
                      decoration: const InputDecoration(hintText: 'Tags (comma separated)'),
                    ),
                    const SizedBox(height: 20),
                    const Text('Folder Color', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _availableColors.map((colorValue) {
                        final isSelected = selectedColor == colorValue;
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              selectedColor = colorValue;
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(colorValue),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.black, width: 3)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      final tags = tagController.text
                          .split(',')
                          .map((t) => t.trim().toLowerCase())
                          .where((t) => t.isNotEmpty)
                          .toList();
                      userVM.createCollection(name, selectedColor, tags: tags);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Detailed view for a specific folder/collection
class CollectionDetailsView extends StatelessWidget {
  final Collection collection;

  const CollectionDetailsView({super.key, required this.collection});

  @override
  Widget build(BuildContext context) {
    final userVM = Provider.of<UserViewModel>(context);

    // Get actual articles belonging to this collection
    final articles = userVM.savedArticles.where((a) => collection.articleIds.contains(a.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Export Reading List',
            onPressed: () => _exportReadingList(context, articles),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded),
            tooltip: 'Delete Folder',
            onPressed: () => _confirmDeleteCollection(context, userVM),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Color(collection.color).withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.folder_rounded, color: Color(collection.color), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${articles.length} articles',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (collection.tags.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tags: ${collection.tags.join(", ")}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      ]
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddArticlesDialog(context, userVM),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Articles'),
                  style: ElevatedButton.styleFrom(elevation: 0),
                )
              ],
            ),
          ),
          Expanded(
            child: articles.isEmpty
                ? const Center(child: Text('This folder is empty.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: articles.length,
                    itemBuilder: (context, index) {
                      final art = articles[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(art.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${art.source} • By ${art.author}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.grey),
                            onPressed: () {
                              userVM.removeArticleFromCollection(collection.id, art.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Removed from folder')),
                              );
                            },
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ReaderView(article: art)),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _exportReadingList(BuildContext context, List<Article> articles) {
    if (articles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No articles to export.')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('# Reading List: ${collection.name}');
    buffer.writeln('Exported on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}');
    buffer.writeln();
    for (int i = 0; i < articles.length; i++) {
      final art = articles[i];
      buffer.writeln('${i + 1}. **[${art.title}](${art.link})**');
      buffer.writeln('   *Source:* ${art.source} | *Author:* ${art.author}');
      buffer.writeln('   *Read progress:* ${(art.readProgress * 100).toInt()}%');
      buffer.writeln();
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Formatted Markdown reading list copied to clipboard!')),
    );
  }

  void _confirmDeleteCollection(BuildContext context, UserViewModel userVM) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Folder?'),
          content: Text('Are you sure you want to delete "${collection.name}"? Articles inside the folder will not be deleted from your saved list.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                userVM.deleteCollection(collection.id);
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to folder list
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAddArticlesDialog(BuildContext context, UserViewModel userVM) {
    // Show all saved articles that are not already in this collection
    final addableArticles = userVM.savedArticles.where((a) => !collection.articleIds.contains(a.id) && a.isSaved && !a.isArchived).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Articles to Folder'),
          content: addableArticles.isEmpty
              ? const Text('All your saved articles are already in this folder.')
              : SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: ListView.builder(
                    itemCount: addableArticles.length,
                    itemBuilder: (context, index) {
                      final art = addableArticles[index];
                      return ListTile(
                        title: Text(art.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(art.source),
                        trailing: const Icon(Icons.add_rounded),
                        onTap: () {
                          userVM.addArticleToCollection(collection.id, art.id);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Added to ${collection.name}')),
                          );
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }
}
