/// Data models for the stories feature, mirroring the Supabase schema.
library;

class StoryPage {
  const StoryPage({
    required this.id,
    required this.storyId,
    required this.position,
    required this.text,
    this.audioUrl,
    this.illustrationUrl,
  });

  final String id;
  final String storyId;
  final int position;
  final String text;
  final String? audioUrl;
  final String? illustrationUrl;

  factory StoryPage.fromJson(Map<String, dynamic> json) {
    return StoryPage(
      id: json['id'] as String,
      storyId: json['story_id'] as String,
      position: (json['position'] as num?)?.toInt() ?? 0,
      text: (json['text'] as String?) ?? '',
      audioUrl: json['audio_url'] as String?,
      illustrationUrl: json['illustration_url'] as String?,
    );
  }
}

class Story {
  const Story({
    required this.id,
    required this.title,
    this.coverTexture,
    this.pageTexture,
    this.authorId,
    this.createdAt,
    this.pages = const [],
  });

  final String id;
  final String title;
  final String? coverTexture;
  final String? pageTexture;
  final String? authorId;
  final DateTime? createdAt;
  final List<StoryPage> pages;

  factory Story.fromJson(Map<String, dynamic> json) {
    final rawPages =
        (json['page'] as List<dynamic>? ?? const [])
            .map((e) => StoryPage.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));

    return Story(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? 'Untitled',
      coverTexture: json['cover_texture'] as String?,
      pageTexture: json['page_texture'] as String?,
      authorId: json['author_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      pages: rawPages,
    );
  }
}
