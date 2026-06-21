import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Per-page narration playback for the reading experience.
///
/// Each story page may carry its own [StoryPage.audioUrl] (narration). This
/// controller owns a single [AudioPlayer] dedicated to that narration — it is
/// *separate* from the app-wide background music, which is paused while the
/// reader is open.
///
/// The reader calls [openPage] whenever a new page is turned to. When
/// [autoplay] is on (the default), opening a page with audio starts it
/// immediately. The reader's audio controls drive [togglePlay], [replay],
/// [seek] and [setAutoplay].
///
/// It's a plain [ChangeNotifier] (not a Riverpod provider) because its lifetime
/// is scoped to a single reader screen: created in the screen's `initState` and
/// disposed in `dispose`.
class PageNarrationController extends ChangeNotifier {
  PageNarrationController() {
    // Surface playback/processing-state changes (play↔pause, buffering,
    // completion) to the controls so the play/pause icon stays in sync.
    _player.playerStateStream.listen((_) => notifyListeners());
  }

  final AudioPlayer _player = AudioPlayer();

  bool _autoplay = true;

  /// The narration URL of the currently open page (null/empty => no narration).
  String? _currentUrl;

  /// Whether opening a new page should immediately start its narration.
  bool get autoplay => _autoplay;

  /// True when the current page has a narration track to play.
  bool get hasAudio => _currentUrl != null && _currentUrl!.isNotEmpty;

  /// True while the dedicated narration player is actually sounding.
  bool get isPlaying => _player.playing;

  /// True while the track is loading or buffering (used to show a spinner).
  bool get isLoading {
    final state = _player.processingState;
    return hasAudio &&
        (state == ProcessingState.loading ||
            state == ProcessingState.buffering);
  }

  /// True once the current track has played to the end.
  bool get isCompleted => _player.processingState == ProcessingState.completed;

  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  /// Emits the play head position for the scrubber.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Called by the reader when a page is turned to. Loads (and, when
  /// [autoplay] is on, plays) that page's narration. Passing null/empty — e.g.
  /// the cover, or a page without narration — stops playback.
  ///
  /// Re-opening the *same* URL is a no-op so the rapid, repeated page-change
  /// events the flip engine emits don't restart audio mid-sentence.
  Future<void> openPage(String? audioUrl) async {
    final normalized = (audioUrl != null && audioUrl.isNotEmpty)
        ? audioUrl
        : null;
    if (normalized == _currentUrl) return;

    _currentUrl = normalized;
    notifyListeners();

    if (normalized == null) {
      await _safe(_player.stop);
      return;
    }

    await _safe(() async {
      await _player.stop();
      await _player.setUrl(normalized);
      if (_autoplay) await _player.play();
    });
  }

  /// Toggles play/pause for the current page's narration. Restarts from the
  /// beginning if the track had finished.
  Future<void> togglePlay() async {
    if (!hasAudio) return;
    await _safe(() async {
      if (_player.playing) {
        await _player.pause();
      } else {
        if (isCompleted) await _player.seek(Duration.zero);
        await _player.play();
      }
    });
  }

  /// Restarts the current page's narration from the beginning.
  Future<void> replay() async {
    if (!hasAudio) return;
    await _safe(() async {
      await _player.seek(Duration.zero);
      await _player.play();
    });
  }

  /// Scrubs to [position] within the current track.
  Future<void> seek(Duration position) async {
    if (!hasAudio) return;
    await _safe(() => _player.seek(position));
  }

  /// Turns automatic narration-on-page-turn on or off. Turning it on while a
  /// page with audio is open starts that page immediately.
  Future<void> setAutoplay(bool value) async {
    if (_autoplay == value) return;
    _autoplay = value;
    notifyListeners();
    if (value && hasAudio && !_player.playing) {
      await togglePlay();
    }
  }

  /// Runs an audio operation, swallowing failures (missing/blocked asset,
  /// autoplay blocked before a user gesture) so the reader never crashes.
  Future<void> _safe(Future<void> Function() op) async {
    try {
      await op();
    } catch (_) {
      // Narration failure should never break the reading experience.
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
