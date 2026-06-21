import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'background_music.dart';

/// Floating music controls shown on every non-reader screen: a mute/unmute
/// toggle plus a settings button that opens the song picker. Wired to the
/// app-wide [backgroundMusicProvider].
class MusicControls extends ConsumerWidget {
  const MusicControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final music = ref.watch(backgroundMusicProvider);
    final controller = ref.read(backgroundMusicProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MagicColors.lilac.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: music.muted ? 'Unmute music' : 'Mute music',
            icon: Icon(
              music.muted ? Icons.volume_off : Icons.volume_up,
              color: MagicColors.gold,
            ),
            onPressed: controller.toggleMute,
          ),
          IconButton(
            tooltip: 'Music settings',
            icon: const Icon(Icons.settings, color: MagicColors.gold),
            onPressed: () => _showMusicSettings(context),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet listing the available tracks; tapping one switches the
/// soundtrack immediately.
Future<void> _showMusicSettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: MagicColors.nightMid,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Consumer(
        builder: (context, ref, _) {
          final music = ref.watch(backgroundMusicProvider);
          final controller = ref.read(backgroundMusicProvider.notifier);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text(
                      'Background music',
                      style: AppTheme.displayFont(fontSize: 18),
                    ),
                  ),
                  for (var i = 0; i < backgroundTracks.length; i++)
                    ListTile(
                      leading: Icon(
                        i == music.trackIndex
                            ? Icons.graphic_eq
                            : Icons.music_note,
                        color: i == music.trackIndex
                            ? MagicColors.gold
                            : MagicColors.lilac,
                      ),
                      title: Text(
                        backgroundTracks[i].label,
                        style: AppTheme.bodyFont(
                          fontWeight: i == music.trackIndex
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: i == music.trackIndex
                              ? MagicColors.gold
                              : MagicColors.textPrimary,
                        ),
                      ),
                      trailing: i == music.trackIndex
                          ? const Icon(Icons.check, color: MagicColors.gold)
                          : null,
                      onTap: () => controller.selectTrack(i),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
