import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import '../services/bookmarks_service.dart';
import '../services/offline_cache_service.dart';
import '../theme/app_theme.dart';
import '../models/bookmark.dart';
import 'glass_widgets.dart';

/// A bottom sheet widget that displays a list of bookmarks, enables offline page caching,
/// and allows selecting bookmarks to navigate to them.
class BookmarksSheet extends StatefulWidget {
  /// The list of bookmarks to display initially.
  final List<Bookmark> initialBookmarks;

  /// The bookmarks service for loading/saving and updating bookmark status.
  final BookmarksService service;

  /// The offline cache service used for checking and managing offline pages.
  final OfflineCacheService offlineCacheService;

  /// The controller of the WebView to perform navigation on.
  final WebViewController controller;

  /// Callback function triggered when a bookmark is selected.
  final ValueChanged<String> onSelect;

  /// Creates a [BookmarksSheet] widget.
  const BookmarksSheet({
    super.key,
    required this.initialBookmarks,
    required this.service,
    required this.offlineCacheService,
    required this.controller,
    required this.onSelect,
  });

  @override
  State<BookmarksSheet> createState() => _BookmarksSheetState();
}

class _BookmarksSheetState extends State<BookmarksSheet> {
  bool _isFullyCached = false;
  bool _isDownloading = false;
  int _downloadedCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final cached = await widget.offlineCacheService.getBulkStatus();
    if (mounted) {
      setState(() {
        _isFullyCached = cached;
      });
    }
  }

  Future<void> _downloadAllPages({bool force = false}) async {
    final isOnline = await widget.offlineCacheService.hasInternetConnection();
    if (!mounted) return;

    if (!isOnline) {
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      Navigator.pop(context); // Close sheet safely
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.only(
            bottom: bottomPadding + 82,
            left: 24,
            right: 24,
          ),
          duration: const Duration(seconds: 2),
          content: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: BorderRadius.circular(16),
            blur: 12.0,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off,
                  color: Color(0xFFFFB84D),
                  size: 16,
                ),
                SizedBox(width: 10),
                Text(
                  'Internet connection required!',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadedCount = 0;
      _totalCount = 0;
    });

    try {
      final urlsObj = await widget.controller.runJavaScriptReturningResult(
          "(() => { "
          "  var links = Array.from(document.querySelectorAll('#sidebar a, .chapter a, nav a, ol.chapter a'));"
          "  if (links.length === 0) {"
          "    links = Array.from(document.querySelectorAll('a')).filter(a => a.href.includes('rust-book.cs.brown.edu'));"
          "  }"
          "  var urls = links.map(a => a.href).filter(h => h && h.startsWith('http'));"
          "  return JSON.stringify(Array.from(new Set(urls)));"
          "})()");

      final rawStr = urlsObj.toString();
      String cleanJson = rawStr;
      if (cleanJson.startsWith('"') && cleanJson.endsWith('"')) {
        cleanJson = jsonDecode(cleanJson) as String;
      }

      final List<dynamic> urls = jsonDecode(cleanJson) as List<dynamic>;
      if (urls.isEmpty) {
        throw 'No chapter links found. Please wait for the book page to load first.';
      }

      if (!mounted) return;
      setState(() {
        _totalCount = urls.length;
      });

      final client = http.Client();
      for (final urlObj in urls) {
        final url = urlObj.toString();
        final alreadyCached = force ? false : await widget.offlineCacheService.hasCachedPage(url);
        if (!alreadyCached) {
          try {
            final response = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
            if (response.statusCode == 200) {
              await widget.offlineCacheService.savePage(url, response.body);
            }
          } catch (_) {}
        }

        if (!mounted) {
          client.close();
          return;
        }
        setState(() {
          _downloadedCount++;
        });
      }
      client.close();

      await widget.offlineCacheService.saveBulkStatus(true);
      if (!mounted) return;
      
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      setState(() {
        _isDownloading = false;
        _isFullyCached = true;
      });
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.only(
            bottom: bottomPadding + 82,
            left: 24,
            right: 24,
          ),
          duration: const Duration(seconds: 2),
          content: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: BorderRadius.circular(16),
            blur: 12.0,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.offline_pin,
                  color: Color(0xFF2083A4),
                  size: 16,
                ),
                SizedBox(width: 10),
                Text(
                  'Book Downloaded for Offline!',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      setState(() {
        _isDownloading = false;
      });
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.only(
            bottom: bottomPadding + 82,
            left: 24,
            right: 24,
          ),
          duration: const Duration(seconds: 3),
          content: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: BorderRadius.circular(16),
            blur: 12.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Download failed: $e',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: GlassContainer(
        blur: 12.0,
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.solidBookmark,
                        color: Color(0xFFFFB84D), size: 16),
                    const SizedBox(width: 8),
                    Text('Bookmarks & Offline',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isDownloading)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06), width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.rustOrange),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Downloading: $_downloadedCount / $_totalCount chapters...',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: _totalCount > 0
                              ? _downloadedCount / _totalCount
                              : 0.0,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          color: AppColors.rustOrange,
                          minHeight: 3,
                        ),
                      ],
                    ),
                  )
                else if (_isFullyCached)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.offline_pin,
                        color: Color(0xFF2083A4), size: 24),
                    title: const Text('Offline Ready',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text(
                        'All book chapters are saved locally on this device.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                    trailing: IconButton(
                      icon: const Icon(Icons.sync,
                          color: Color(0xFF2083A4), size: 20),
                      tooltip: 'Sync & Update Cache',
                      onPressed: () => _downloadAllPages(force: true),
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'The entire book is cached for offline reading!')),
                      );
                    },
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download_for_offline,
                        color: AppColors.rustOrange, size: 24),
                    title: const Text('Download Entire Book',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text(
                        'Cache all book chapters locally to read without internet.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                    onTap: _downloadAllPages,
                  ),
                const Divider(height: 16, color: AppColors.glassBorder),
                Expanded(
                  child: () {
                    final items = widget.initialBookmarks;
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No bookmarks yet — tap the bookmark icon while reading to save a page.',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 16,
                        color: AppColors.glassBorder,
                      ),
                      itemBuilder: (_, i) {
                        final b = items[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const FaIcon(FontAwesomeIcons.fileLines,
                              color: Color(0xFFFFB84D), size: 16),
                          title: Text(b.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                          subtitle: Text(b.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 11)),
                          onTap: () => widget.onSelect(b.url),
                        );
                      },
                    );
                  }(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
