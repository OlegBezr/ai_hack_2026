import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import 'models.dart';

/// All Supabase data access for the stories feature. PostgREST calls are
/// RLS-protected; the edge-function calls carry the user's JWT automatically.
class StoriesRepository {
  StoriesRepository(this._client);

  final SupabaseClient _client;

  // --- Stories ---

  Future<List<Story>> listStories() async {
    final rows = await _client
        .from('story')
        .select('*, page(*)')
        .order('created_at');
    return (rows as List<dynamic>)
        .map((e) => Story.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Story> createStory(String title) async {
    final row = await _client
        .from('story')
        .insert({'title': title})
        .select('*, page(*)')
        .single();
    return Story.fromJson(row);
  }

  Future<void> updateStory(String id, {String? title}) async {
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title;
    if (patch.isEmpty) return;
    await _client.from('story').update(patch).eq('id', id);
  }

  Future<void> deleteStory(String id) async {
    await _client.from('story').delete().eq('id', id);
  }

  // --- Pages ---

  Future<StoryPage> createPage(
    String storyId,
    int position,
    String text,
  ) async {
    final row = await _client
        .from('page')
        .insert({'story_id': storyId, 'position': position, 'text': text})
        .select()
        .single();
    return StoryPage.fromJson(row);
  }

  Future<void> updatePage(String id, {String? text, int? position}) async {
    final patch = <String, dynamic>{};
    if (text != null) patch['text'] = text;
    if (position != null) patch['position'] = position;
    if (patch.isEmpty) return;
    await _client.from('page').update(patch).eq('id', id);
  }

  Future<void> deletePage(String id) async {
    await _client.from('page').delete().eq('id', id);
  }

  // --- Edge functions ---

  /// Generates an illustration for [pageId]; returns the public image URL.
  /// Can take tens of seconds (Midjourney).
  Future<String?> generateIllustration(String pageId, String prompt) async {
    final res = await _client.functions.invoke(
      'generate-illustration',
      body: {'page_id': pageId, 'prompt': prompt},
    );
    final data = res.data;
    if (data is Map && data['illustration_url'] is String) {
      return data['illustration_url'] as String;
    }
    return null;
  }

  /// Generates narration audio for [pageId]; returns the public audio URL.
  Future<String?> generateAudio(String pageId, {String? text}) async {
    final body = <String, dynamic>{'page_id': pageId};
    if (text != null) body['text'] = text;
    final res = await _client.functions.invoke('generate-audio', body: body);
    final data = res.data;
    if (data is Map && data['audio_url'] is String) {
      return data['audio_url'] as String;
    }
    return null;
  }
}

final storiesRepositoryProvider = Provider<StoriesRepository>(
  (ref) => StoriesRepository(ref.watch(supabaseClientProvider)),
);

/// The user's stories list, with pages eagerly loaded. Refreshable.
class StoriesNotifier extends AsyncNotifier<List<Story>> {
  @override
  Future<List<Story>> build() {
    return ref.watch(storiesRepositoryProvider).listStories();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(storiesRepositoryProvider).listStories(),
    );
  }
}

final storiesProvider = AsyncNotifierProvider<StoriesNotifier, List<Story>>(
  StoriesNotifier.new,
);

/// A single story (with pages) loaded by id. Family keeps editor state fresh.
final storyProvider = FutureProvider.family<Story, String>((ref, id) async {
  final repo = ref.watch(storiesRepositoryProvider);
  final stories = await repo.listStories();
  return stories.firstWhere(
    (s) => s.id == id,
    orElse: () => throw StateError('Story not found: $id'),
  );
});
