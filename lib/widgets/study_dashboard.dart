import 'package:flutter/material.dart';
import '../services/bookmarks_service.dart';
import '../theme/app_theme.dart';
import 'glass_widgets.dart';

/// A dashboard widget that displays reading progress statistics, total time spent reading,
/// the resume button for the last visited URL, and a search-supported chapter index.
class StudyDashboard extends StatelessWidget {
  /// The total reading time in seconds accumulated by the user.
  final int readingTimeSeconds;

  /// A list of URLs corresponding to chapters that have been marked as read.
  final List<String> readChapters;

  /// The URL of the page the user was last visiting.
  final String lastVisitedUrl;

  /// The list of all chapter elements represented as maps of 'title' and 'url'.
  final List<Map<String, String>> chapters;

  /// The controller of the text field used to search the chapter list.
  final TextEditingController searchController;

  /// Callback triggered when a chapter is selected.
  final ValueChanged<String> onChapterSelect;

  /// The bookmarks service to load and persist bookmarks and stats.
  final BookmarksService bookmarksService;

  /// Creates a [StudyDashboard] widget.
  const StudyDashboard({
    super.key,
    required this.readingTimeSeconds,
    required this.readChapters,
    required this.lastVisitedUrl,
    required this.chapters,
    required this.searchController,
    required this.onChapterSelect,
    required this.bookmarksService,
  });

  @override
  Widget build(BuildContext context) {
    // Format reading time (seconds) to hours and minutes
    final hours = readingTimeSeconds ~/ 3600;
    final minutes = (readingTimeSeconds % 3600) ~/ 60;
    final seconds = readingTimeSeconds % 60;
    final timeStr = hours > 0
        ? '${hours}h ${minutes}m'
        : minutes > 0
            ? '${minutes}m ${seconds}s'
            : '${seconds}s';

    // Calculate covered progress percentage
    final totalChapters = chapters.length;
    int readCount = 0;
    for (final ch in chapters) {
      if (readChapters.contains(ch['url'])) {
        readCount++;
      }
    }
    final progressPercent = totalChapters > 0 ? readCount / totalChapters : 0.0;
    final progressPercentText =
        '${(progressPercent * 100).toStringAsFixed(0)}%';

    final filteredChapters = chapters.where((ch) {
      final query = searchController.text.trim().toLowerCase();
      return (ch['title'] ?? '').toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(20, 16, 20, 100), // Clears bottom navbar
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title & Compact Stats Row
          Row(
            children: [
              // Small circular progress meter
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progressPercent,
                      strokeWidth: 4.5,
                      color: const Color(0xFFDE7B3F),
                      backgroundColor: Colors.white10,
                    ),
                    Text(
                      progressPercentText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Compact stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$readCount of $totalChapters Chapters Covered',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Time Spent: $timeStr',
                      style: const TextStyle(
                        color: Color(0xFF2083A4),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: searchController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search chapters index...',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                prefixIcon: Icon(Icons.search,
                    color: Colors.white.withValues(alpha: 0.4), size: 18),
                suffixIcon: searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          searchController.clear();
                          // Force UI refresh handled by parent via onChanged or rebuild
                        },
                        child: Icon(Icons.clear,
                            color: Colors.white.withValues(alpha: 0.4),
                            size: 18),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Resume reading section
          GestureDetector(
            onTap: () => onChapterSelect(lastVisitedUrl),
            child: GlassContainer(
              blur: 0.0, // Disable blur to avoid rendering overhead on rebuilds
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              fillColor: const Color(0xFFDE7B3F).withValues(alpha: 0.05),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_filled,
                      color: Color(0xFFDE7B3F), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CONTINUE READING',
                          style: TextStyle(
                            color: Color(0xFFDE7B3F),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          () {
                            String chapterTitle = 'Introduction';
                            for (final ch in chapters) {
                              if (lastVisitedUrl == ch['url'] ||
                                  lastVisitedUrl.contains(ch['url']!)) {
                                chapterTitle = ch['title']!;
                                break;
                              }
                            }
                            return chapterTitle;
                          }(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      color: Colors.white38, size: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Chapters list title
          const Text(
            'CHAPTERS INDEX',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),

          // 4. Scrollable list of chapters
          Expanded(
            child: filteredChapters.isEmpty
                ? Center(
                    child: Text(
                      'No chapters match "${searchController.text}"',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredChapters.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final ch = filteredChapters[index];
                      final url = ch['url']!;
                      final title = ch['title']!;
                      final isRead = readChapters.contains(url);

                      return TweenAnimationBuilder<double>(
                        key: ValueKey('${ch['url']}_$index'),
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: Duration(
                            milliseconds: 350 + (index * 25).clamp(0, 200)),
                        curve: Curves.easeOutCubic,
                        builder: (context, animValue, child) {
                          return Opacity(
                            opacity: animValue,
                            child: Transform.translate(
                              offset: Offset(0, 15 * (1.0 - animValue)),
                              child: child,
                            ),
                          );
                        },
                        child: GestureDetector(
                          onTap: () => onChapterSelect(url),
                          child: GlassContainer(
                            blur:
                                0.0, // Disable BackdropFilter on list items to avoid GPU rasterization lag during scroll!
                            borderRadius: BorderRadius.circular(16),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(
                                  isRead
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isRead
                                      ? const Color(0xFF2083A4)
                                      : AppColors.textMuted
                                          .withValues(alpha: 0.3),
                                  size: 20,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      color: isRead
                                          ? Colors.white
                                          : AppColors.textPrimary
                                              .withValues(alpha: 0.8),
                                      fontSize: 13,
                                      fontWeight: isRead
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: Colors.white24, size: 16),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
