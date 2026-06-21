import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/background_music.dart';
import '../audio/music_controls.dart';
import 'app_theme.dart';
import 'magical_background.dart';

/// A [Scaffold] that floats on the shared twilight [MagicalBackground]. Use it
/// in place of a plain Scaffold to get the magical backdrop for free.
///
/// By default it also overlays the floating [MusicControls] (bottom-left) and
/// keeps the app-wide soundtrack playing. Screens that should be silent — the
/// reader — pass `showMusicControls: false` and pause the music themselves.
class MagicScaffold extends ConsumerWidget {
  const MagicScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.showMusicControls = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final bool showMusicControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (showMusicControls) {
      // Keep the soundtrack running on every ordinary screen. Idempotent, so
      // re-running it per build is harmless; the first tap satisfies browser
      // autoplay if the initial attempt was blocked.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(backgroundMusicProvider.notifier).ensureStarted(),
      );
    }
    return MagicalBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        body: showMusicControls
            ? Stack(
                children: [
                  Positioned.fill(child: body),
                  const Positioned(
                    left: 12,
                    bottom: 12,
                    child: SafeArea(child: MusicControls()),
                  ),
                ],
              )
            : body,
      ),
    );
  }
}

/// A frosted-glass panel — translucent, blurred, with a soft luminous border.
/// The signature surface of the magical theme.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderRadius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withValues(alpha: 0.06),
          child: InkWell(
            onTap: onTap,
            splashColor: MagicColors.gold.withValues(alpha: 0.10),
            highlightColor: MagicColors.lilac.withValues(alpha: 0.06),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
                border: Border.all(
                  color: MagicColors.lilac.withValues(alpha: 0.28),
                  width: 1,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The app wordmark — engraved fantasy caps with a warm golden glow, optionally
/// flanked by a sparkle. Used on landing / auth surfaces.
class MagicWordmark extends StatelessWidget {
  const MagicWordmark({
    super.key,
    required this.text,
    this.fontSize = 40,
    this.icon = Icons.auto_awesome,
  });

  final String text;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, color: MagicColors.gold, size: fontSize * 0.9)
              .withGlow(MagicColors.gold),
        if (icon != null) SizedBox(height: fontSize * 0.3),
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTheme.displayFont(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ).copyWith(
            shadows: [
              Shadow(
                color: MagicColors.gold.withValues(alpha: 0.55),
                blurRadius: 24,
              ),
              const Shadow(color: Color(0xAA000000), blurRadius: 2),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small golden glow halo behind an icon.
extension GlowExtension on Widget {
  Widget withGlow(Color color, {double blur = 18}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: blur)],
      ),
      child: this,
    );
  }
}
