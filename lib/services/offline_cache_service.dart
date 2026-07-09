/// Author: Amit (amitxd)
/// Description: Offline caching service to save pages to disk, check for active connectivity, and track bulk downloads.

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheService {
  static const _subDir = 'rust_book_offline_cache';
  static const _bulkCacheKey = 'rust_book_fully_cached_bulk';

  /// Generates a safe local filename based on the URL path.
  String _safeFilename(String url) {
    // Standardize URL formatting
    String cleanUrl = url.trim().toLowerCase();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    // Extract path segment to keep name clean and readable
    final uri = Uri.parse(cleanUrl);
    String pathSeg = uri.path.replaceAll('/', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
    if (pathSeg.isEmpty || pathSeg == '_') {
      pathSeg = 'index';
    }
    return '$pathSeg.html';
  }

  /// Gets the reference to the local file representing the cached webpage content.
  Future<File> _getLocalFile(String url) async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/$_subDir');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final filename = _safeFilename(url);
    return File('${cacheDir.path}/$filename');
  }

  /// Checks if active internet connectivity is available using a direct socket connection.
  Future<bool> hasInternetConnection() async {
    try {
      // Connect directly to Google Public DNS to avoid slow DNS resolution timeouts when offline
      final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(milliseconds: 1500));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Saves the outer HTML string of a webpage to local disk storage.
  Future<void> savePage(String url, String html) async {
    if (html.isEmpty) return;
    try {
      final file = await _getLocalFile(url);
      await file.writeAsString(html, flush: true);
    } catch (_) {
      // Fail silently
    }
  }

  /// Checks if a page has been cached locally on disk.
  Future<bool> hasCachedPage(String url) async {
    try {
      final file = await _getLocalFile(url);
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  /// Reads and returns the cached HTML string for the given URL.
  Future<String?> getCachedPage(String url) async {
    try {
      final file = await _getLocalFile(url);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {
      // Fallback to null
    }
    return null;
  }

  /// Saves whether the entire book has been downloaded for offline reading.
  Future<void> saveBulkStatus(bool fullyCached) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bulkCacheKey, fullyCached);
  }

  /// Checks if the entire book has been downloaded for offline reading.
  Future<bool> getBulkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_bulkCacheKey) ?? false;
  }
}
