import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/bookmark.dart';

/// A service that manages bookmarks, user preferences, API keys, chat history,
/// and reading progress metrics using SharedPreferences and FlutterSecureStorage.
class BookmarksService {
  static const _key = 'rust_book_bookmarks_v1';
  static const _secureStorage = FlutterSecureStorage();

  /// Loads all saved bookmarks, ordered by the date and time they were saved (newest first).
  Future<List<Bookmark>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => Bookmark.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  /// Saves the updated list of bookmarks to SharedPreferences.
  Future<void> _save(List<Bookmark> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      items.map((b) => jsonEncode(b.toJson())).toList(),
    );
  }

  /// Checks if a page with the given [url] has been bookmarked.
  Future<bool> isBookmarked(String url) async {
    final items = await load();
    return items.any((b) => b.url == url);
  }

  /// Toggles the bookmark for [url]/[title]; returns true if now bookmarked.
  Future<bool> toggle(String url, String title) async {
    final items = await load();
    final exists = items.indexWhere((b) => b.url == url);
    if (exists >= 0) {
      items.removeAt(exists);
      await _save(items);
      return false;
    } else {
      items.add(Bookmark(url: url, title: title, savedAt: DateTime.now()));
      await _save(items);
      return true;
    }
  }

  /// Removes the bookmark for the given [url].
  Future<void> remove(String url) async {
    final items = await load();
    items.removeWhere((b) => b.url == url);
    await _save(items);
  }

  static const _lastVisitedKey = 'rust_book_last_visited_url';

  /// Saves the last visited [url] for restoring the session on next app launch.
  Future<void> saveLastVisitedUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastVisitedKey, url);
  }

  /// Retrieves the last visited URL, defaulting to the Rust Book home page.
  Future<String> getLastVisitedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastVisitedKey) ??
        'https://rust-book.cs.brown.edu/';
  }

  static const _apiKeyKey = 'rust_book_gemini_api_key';
  static const _modelKey = 'rust_book_gemini_model';

  /// Saves the user's Gemini API key securely in secure storage.
  Future<void> saveGeminiApiKey(String key) async {
    // Encrypt and write to secure storage (Keychain on iOS, Keystore/AES-CBC on Android)
    await _secureStorage.write(key: _apiKeyKey, value: key);
  }

  /// Retrieves the user's Gemini API key from secure storage, returning null if not found.
  Future<String?> getGeminiApiKey() async {
    // Read and decrypt from secure storage
    return await _secureStorage.read(key: _apiKeyKey);
  }

  /// Saves the preferred Gemini [model] name to SharedPreferences.
  Future<void> saveGeminiModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, model);
  }

  /// Retrieves the selected Gemini model, defaulting to 'gemini-3.1-flash-lite'.
  Future<String> getGeminiModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelKey) ?? 'gemini-3.1-flash-lite';
  }

  static const _chatHistoryKey = 'rust_book_gemini_chat_history_v1';

  /// Serializes and writes Gemini chat history (raw text/flags only, ignoring widgets) to SharedPreferences.
  Future<void> saveChatHistory(List<Map<String, dynamic>> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final rawMessages = messages.map((m) {
      return {
        'text': m['text'],
        'isUser': m['isUser'],
        if (m.containsKey('isError')) 'isError': m['isError'],
      };
    }).toList();
    await prefs.setString(_chatHistoryKey, jsonEncode(rawMessages));
  }

  /// Loads and parses Gemini chat history from SharedPreferences.
  Future<List<Map<String, dynamic>>> loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chatHistoryKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((m) => Map<String, dynamic>.from(m as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  // Reading Progress and Metrics Persistence
  static const _readChaptersKey = 'rust_book_read_chapters_v1';
  static const _readingTimeSecondsKey = 'rust_book_reading_time_seconds_v1';

  /// Gets the list of URLs of chapters that have been marked as read.
  Future<List<String>> getReadChapters() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_readChaptersKey) ?? [];
  }

  /// Marks a chapter with the given [url] as read.
  Future<void> markChapterAsRead(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_readChaptersKey) ?? [];
    if (!current.contains(url)) {
      current.add(url);
      await prefs.setStringList(_readChaptersKey, current);
    }
  }

  /// Retrieves the total reading time in seconds accumulated by the user.
  Future<int> getReadingTimeSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_readingTimeSecondsKey) ?? 0;
  }

  /// Adds [seconds] to the user's total reading time.
  Future<void> addReadingTime(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_readingTimeSecondsKey) ?? 0;
    await prefs.setInt(_readingTimeSecondsKey, current + seconds);
  }

  static const _chaptersIndexKey = 'rust_book_chapters_index_v1';

  /// Saves the cached list of chapters to SharedPreferences.
  Future<void> saveChaptersIndex(List<Map<String, String>> chapters) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = chapters.map((c) => jsonEncode(c)).toList();
    await prefs.setStringList(_chaptersIndexKey, raw);
  }

  /// Retrieves the cached index of chapters.
  Future<List<Map<String, String>>> getChaptersIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_chaptersIndexKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return raw
          .map((s) => Map<String, String>.from(jsonDecode(s) as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
