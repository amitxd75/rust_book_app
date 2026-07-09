class Bookmark {
  final String url;
  final String title;
  final DateTime savedAt;

  Bookmark({required this.url, required this.title, required this.savedAt});

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'savedAt': savedAt.toIso8601String(),
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        url: json['url'] as String,
        title: json['title'] as String,
        savedAt: DateTime.parse(json['savedAt'] as String),
      );
}
