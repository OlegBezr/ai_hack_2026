/// Data models for the stories feature, mirroring the Supabase schema.
library;

import 'package:flutter/material.dart';

/// Story-wide page styling (font, sizing, colors, alignment) applied to every
/// page of the story. Mirrors the `story.style` JSONB column; every field is
/// optional and null means "use the reader default". [backgroundColor] is the
/// solid page background color (preset or custom).
class StoryStyle {
  const StoryStyle({
    this.fontFamily,
    this.fontSizeScale,
    this.textColor,
    this.backgroundColor,
    this.textAlign,
  });

  /// One of the curated families exposed in the editor ('Serif', 'Sans',
  /// 'Mono'). Resolution to an actual font happens in the UI layer.
  final String? fontFamily;

  /// Multiplier applied to the base body font size (~0.8 .. 2.0). null => 1.0.
  final double? fontSizeScale;

  /// Text color as a hex string, e.g. '#1A1A1A'.
  final String? textColor;

  /// Solid page background fallback (used when there is no page texture).
  final String? backgroundColor;

  /// One of: 'left', 'center', 'right', 'justify'.
  final String? textAlign;

  bool get isEmpty =>
      fontFamily == null &&
      fontSizeScale == null &&
      textColor == null &&
      backgroundColor == null &&
      textAlign == null;

  factory StoryStyle.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const StoryStyle();
    return StoryStyle(
      fontFamily: json['fontFamily'] as String?,
      fontSizeScale: (json['fontSizeScale'] as num?)?.toDouble(),
      textColor: json['textColor'] as String?,
      backgroundColor: json['backgroundColor'] as String?,
      textAlign: json['textAlign'] as String?,
    );
  }

  /// JSON with null fields omitted (keeps the stored blob tidy).
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (fontFamily != null) json['fontFamily'] = fontFamily;
    if (fontSizeScale != null) json['fontSizeScale'] = fontSizeScale;
    if (textColor != null) json['textColor'] = textColor;
    if (backgroundColor != null) json['backgroundColor'] = backgroundColor;
    if (textAlign != null) json['textAlign'] = textAlign;
    return json;
  }

  StoryStyle copyWith({
    String? fontFamily,
    double? fontSizeScale,
    String? textColor,
    String? backgroundColor,
    String? textAlign,
  }) {
    return StoryStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSizeScale: fontSizeScale ?? this.fontSizeScale,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textAlign: textAlign ?? this.textAlign,
    );
  }

  /// Resolved [TextAlign] for rendering. Defaults to left.
  TextAlign get resolvedTextAlign {
    switch (textAlign) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  /// Parses a '#RRGGBB' / '#AARRGGBB' hex string into a [Color], or null.
  static Color? parseColor(String? hex) {
    if (hex == null) return null;
    var value = hex.replaceAll('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  Color? get resolvedTextColor => parseColor(textColor);
  Color? get resolvedBackgroundColor => parseColor(backgroundColor);
}

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

/// A page returned by the `compose-story` edge function: the persisted page id
/// plus the (transient) Midjourney prompt for its illustration. The prompt is
/// not stored in the DB — it's only used to immediately request the artwork.
class ComposedPagePrompt {
  const ComposedPagePrompt({
    required this.id,
    required this.position,
    required this.text,
    required this.illustrationPrompt,
  });

  final String id;
  final int position;
  final String text;
  final String illustrationPrompt;

  factory ComposedPagePrompt.fromJson(Map<String, dynamic> json) {
    return ComposedPagePrompt(
      id: json['id'] as String,
      position: (json['position'] as num?)?.toInt() ?? 0,
      text: (json['text'] as String?) ?? '',
      illustrationPrompt: (json['illustration_prompt'] as String?) ?? '',
    );
  }
}

/// Result of `compose-story`: a freshly created story (id + title) and the
/// per-page prompts to drive parallel illustration/audio generation, plus a
/// cover-art prompt for `generate-texture`.
class ComposedStoryResult {
  const ComposedStoryResult({
    required this.storyId,
    required this.title,
    required this.coverPrompt,
    required this.pages,
  });

  final String storyId;
  final String title;
  final String coverPrompt;
  final List<ComposedPagePrompt> pages;

  factory ComposedStoryResult.fromJson(Map<String, dynamic> json) {
    final rawPages = (json['pages'] as List<dynamic>? ?? const [])
        .map((e) => ComposedPagePrompt.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return ComposedStoryResult(
      storyId: json['story_id'] as String,
      title: (json['title'] as String?) ?? 'Untitled',
      coverPrompt: (json['cover_prompt'] as String?) ?? '',
      pages: rawPages,
    );
  }
}

class Story {
  const Story({
    required this.id,
    required this.title,
    this.coverTexture,
    this.style = const StoryStyle(),
    this.authorId,
    this.createdAt,
    this.pages = const [],
  });

  final String id;
  final String title;
  final String? coverTexture;
  final StoryStyle style;
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
      style: StoryStyle.fromJson(json['style'] as Map<String, dynamic>?),
      authorId: json['author_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      pages: rawPages,
    );
  }
}
