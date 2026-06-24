import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:newsroom/ui/features/profile/view_models/user_view_model.dart';
import 'package:newsroom/ui/features/reader/views/reader_view.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  // Helper to check if a date string is in the read activity list
  bool _hasReadOnDate(List<String> readDates, DateTime date) {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return readDates.contains(dateStr);
  }

  // Get start date of current month
  DateTime _startOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  // Get total days in current month
  int _daysInMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0).day;
  }

  Color getSourceColor(String source) {
    switch (source) {
      case 'The New York Times':
        return const Color(0xFF1A1A1A);
      case 'The Wall Street Journal':
        return const Color(0xFF0F2537);
      case 'Financial Times':
        return const Color(0xFF381519);
      case 'The Times':
      case 'The Independent':
        return const Color(0xFF0F1E36);
      case 'The Guardian':
        return const Color(0xFF005689);
      case 'The Economist':
        return const Color(0xFFD51A22);
      case 'Project Syndicate':
        return const Color(0xFF0E5B5B);
      case 'Reuters':
      case 'The Conversation':
        return const Color(0xFFDF5800);
      case 'BBC':
        return const Color(0xFF900B0B);
      case 'Al Jazeera':
        return const Color(0xFFE88A00);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userVM = Provider.of<UserViewModel>(context);
    final theme = Theme.of(context);
    final profile = userVM.profile;

    // Filter Read Later Queue (which is stored in savedArticles where isReadLater is true)
    final readLaterArticles = userVM.savedArticles.where((a) => a.isReadLater).toList();

    // Statistics calculations
    // Filter articles read in the last 7 days (readProgress >= 0.9)
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    final readArticles = userVM.savedArticles.where((a) => a.readProgress >= 0.9 && a.savedDate != null && a.savedDate!.isAfter(oneWeekAgo)).toList();
    
    // Estimate word count (roughly 1200 words per opinion piece)
    final estimatedWordsRead = readArticles.length * 1200;

    // Calculate source distribution for weekly digest
    final Map<String, int> sourceCount = {};
    for (var art in readArticles) {
      sourceCount[art.source] = (sourceCount[art.source] ?? 0) + 1;
    }
    
    final totalRead = readArticles.isEmpty ? 1 : readArticles.length;
    final sortedSources = sourceCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calendar Calculations
    final startOfMon = _startOfMonth();
    final firstDayOfWeek = startOfMon.weekday; // 1 = Monday, 7 = Sunday
    final totalDays = _daysInMonth();
    final calendarCellCount = totalDays + (firstDayOfWeek - 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Streak Counter Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'READING STREAK',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${profile.streakCount} Days',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.streakCount > 0 ? 'Keep the fire burning! Read today.' : 'Start reading to build a streak!',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.orangeAccent,
                    size: 64,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Streak Calendar Title
          const Text(
            'Activity Calendar',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),

          // Visual Calendar Grid
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    '${_monthName(DateTime.now().month)} ${DateTime.now().year}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  // Weekday headers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                      return SizedBox(
                        width: 32,
                        child: Text(day, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: calendarCellCount,
                    itemBuilder: (context, index) {
                      final dayIndex = index - (firstDayOfWeek - 1);
                      if (dayIndex < 0 || dayIndex >= totalDays) {
                        return const SizedBox.shrink(); // Empty padding cell
                      }

                      final dayNum = dayIndex + 1;
                      final date = DateTime(DateTime.now().year, DateTime.now().month, dayNum);
                      final isRead = _hasReadOnDate(profile.readDates, date);
                      final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;

                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRead
                              ? theme.primaryColor
                              : (isToday ? theme.primaryColor.withValues(alpha: 0.15) : Colors.transparent),
                          border: isToday
                              ? Border.all(color: theme.primaryColor, width: 1.5)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: (isRead || isToday) ? FontWeight.bold : FontWeight.normal,
                            color: isRead
                                ? Colors.white
                                : (isToday ? theme.primaryColor : theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7)),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Weekly Digest Title
          const Text(
            'Weekly Digest Stats',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),

          // Stats digest Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statBlock('Articles Read', '${readArticles.length}', Icons.menu_book_rounded, theme),
                      Container(width: 1, height: 40, color: theme.dividerColor),
                      _statBlock('Words Read (Est)', '$estimatedWordsRead', Icons.query_stats_rounded, theme),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text('Newspaper Coverage Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  if (readArticles.isEmpty)
                    const Text('Read articles to see source distributions.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12))
                  else
                    ...sortedSources.map((entry) {
                      final source = entry.key;
                      final count = entry.value;
                      final percent = count / totalRead;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(source, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Text('$count articles (${(percent * 100).toInt()}%)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percent,
                                minHeight: 6,
                                color: getSourceColor(source),
                                backgroundColor: Colors.grey.shade200,
                              ),
                            )
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Read Later Queue Title
          const Text(
            'Read Later Queue',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),

          // Read Later Queue
          readLaterArticles.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'Your read later inbox is empty.',
                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: readLaterArticles.length,
                  itemBuilder: (context, index) {
                    final art = readLaterArticles[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: getSourceColor(art.source).withValues(alpha: 0.1),
                          child: Icon(Icons.watch_later_rounded, color: getSourceColor(art.source), size: 20),
                        ),
                        title: Text(art.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(art.source),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_sweep_rounded, color: Colors.grey),
                          onPressed: () {
                            userVM.toggleReadLater(art, false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Removed from queue')),
                            );
                          },
                          tooltip: 'Remove from Queue',
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
        ],
      ),
    );
  }

  Widget _statBlock(String label, String value, IconData icon, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, color: theme.primaryColor, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  String _monthName(int m) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[m - 1];
  }
}
