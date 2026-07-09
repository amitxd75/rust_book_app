/// Represents a bookmarked page or chapter in the Rust Book.
class Bookmark {
  /// The URL of the bookmarked page.
  final String url;

  /// The title or name of the bookmarked page/chapter.
  final String title;

  /// The date and time when the bookmark was saved.
  final DateTime savedAt;

  /// Creates a new [Bookmark] instance.
  Bookmark({required this.url, required this.title, required this.savedAt});

  /// Converts this bookmark instance into a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'savedAt': savedAt.toIso8601String(),
      };

  /// Creates a [Bookmark] instance from a JSON map.
  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        url: json['url'] as String,
        title: json['title'] as String,
        savedAt: DateTime.parse(json['savedAt'] as String),
      );
}
