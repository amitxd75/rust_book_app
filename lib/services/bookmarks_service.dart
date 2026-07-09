import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/bookmark.dart';

class BookmarksService {
  static const _key = 'rust_book_bookmarks_v1';
  static const _secureStorage = FlutterSecureStorage();

  Future<List<Bookmark>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => Bookmark.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  Future<void> _save(List<Bookmark> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      items.map((b) => jsonEncode(b.toJson())).toList(),
    );
  }

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

  Future<void> remove(String url) async {
    final items = await load();
    items.removeWhere((b) => b.url == url);
    await _save(items);
  }

  static const _lastVisitedKey = 'rust_book_last_visited_url';

  Future<void> saveLastVisitedUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastVisitedKey, url);
  }

  Future<String> getLastVisitedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastVisitedKey) ?? 'https://rust-book.cs.brown.edu/';
  }

  static const _apiKeyKey = 'rust_book_gemini_api_key';
  static const _modelKey = 'rust_book_gemini_model';

  Future<void> saveGeminiApiKey(String key) async {
    // Encrypt and write to secure storage (Keychain on iOS, Keystore/AES-CBC on Android)
    await _secureStorage.write(key: _apiKeyKey, value: key);
  }

  Future<String?> getGeminiApiKey() async {
    // Read and decrypt from secure storage
    return await _secureStorage.read(key: _apiKeyKey);
  }

  Future<void> saveGeminiModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, model);
  }

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
}
