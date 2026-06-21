import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// A selectable background music track bundled in assets/audio/.
class MusicTrack {
  const MusicTrack({required this.label, required this.asset});

  final String label;
  final String asset;
}

/// The available ambient tracks, in the order shown in the picker.
const backgroundTracks = <MusicTrack>[
  MusicTrack(
    label: 'Dreamy',
    asset: 'assets/audio/Lilac Skies - Dreamy [Thematic].mp3',
  ),
  MusicTrack(
    label: 'Magical',
    asset: 'assets/audio/Lilac Skies - Magical [Thematic].mp3',
  ),
  MusicTrack(
    label: 'Dozing Off',
    asset: 'assets/audio/Damien Sebe - dozing off [Thematic].mp3',
  ),
];

/// Immutable view of the music controller, watched by the UI.
class BackgroundMusicState {
  const BackgroundMusicState({this.trackIndex = 0, this.muted = false});

  final int trackIndex;
  final bool muted;

  MusicTrack get track => backgroundTracks[trackIndex];

  BackgroundMusicState copyWith({int? trackIndex, bool? muted}) =>
      BackgroundMusicState(
        trackIndex: trackIndex ?? this.trackIndex,
        muted: muted ?? this.muted,
      );
}

const double _kVolume = 0.3;

/// App-wide background music: a single looping [AudioPlayer] shared across
/// every screen so the soundtrack keeps playing while the user navigates.
///
/// Lives at the root [ProviderScope], so it is created once and disposed only
/// when the app exits.
class BackgroundMusicController extends Notifier<BackgroundMusicState> {
  final _player = AudioPlayer();
  bool _loaded = false;

  @override
  BackgroundMusicState build() {
    ref.onDispose(_player.dispose);
    _player.setLoopMode(LoopMode.one);
    return const BackgroundMusicState();
  }

  /// Loads the current track (once) and starts playback unless muted.
  ///
  /// Safe to call from any user gesture or screen mount — it's idempotent.
  /// Browsers block audio autoplay until the user interacts with the page, so
  /// the first real start typically happens from a tap (e.g. mute/picker).
  Future<void> ensureStarted() async {
    try {
      if (!_loaded) {
        await _player.setAsset(state.track.asset);
        await _player.setVolume(state.muted ? 0 : _kVolume);
        _loaded = true;
      }
      if (!state.muted && !_player.playing) {
        await _player.play();
      }
    } catch (_) {
      // Asset missing or autoplay blocked — fail silently; app still works.
    }
  }

  /// Pauses playback without touching the mute state — used while the user is
  /// in reading mode, where the soundtrack should fall silent. Call
  /// [ensureStarted] afterwards to resume (it respects the mute state).
  Future<void> pause() async {
    await _player.pause();
  }

  /// Toggles sound on/off. Muting pauses the player; unmuting resumes it.
  Future<void> toggleMute() async {
    final muted = !state.muted;
    state = state.copyWith(muted: muted);
    if (muted) {
      await _player.setVolume(0);
      await _player.pause();
    } else {
      await _player.setVolume(_kVolume);
      await ensureStarted();
    }
  }

  /// Switches to another track and plays it immediately (unless muted).
  Future<void> selectTrack(int index) async {
    if (index < 0 || index >= backgroundTracks.length) return;
    if (index == state.trackIndex && _loaded) return;
    state = state.copyWith(trackIndex: index);
    try {
      // Fully tear down the currently-looping source before swapping. With
      // LoopMode.one, calling setAsset on a still-playing player can be
      // swallowed and the old track keeps looping — stop() first avoids that.
      await _player.stop();
      await _player.setAsset(state.track.asset);
      _loaded = true;
      await _player.setVolume(state.muted ? 0 : _kVolume);
      if (!state.muted) await _player.play();
    } catch (_) {
      // Asset missing — ignore; selection still updates in the UI.
    }
  }
}

final backgroundMusicProvider =
    NotifierProvider<BackgroundMusicController, BackgroundMusicState>(
      BackgroundMusicController.new,
    );
