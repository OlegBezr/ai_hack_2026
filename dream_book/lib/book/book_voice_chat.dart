import 'package:flutter/material.dart';

import '../deepgram/voice_agent_service.dart';
import '../stories/data/models.dart';
import '../theme/app_theme.dart';

/// Opens the live voice-to-voice chat for [story] as a tall modal sheet.
///
/// Launched from the reader's top bar. The sheet owns a [VoiceAgentController]
/// for its lifetime: it connects on open and tears the mic + socket down when
/// dismissed.
Future<void> showBookVoiceChat(BuildContext context, Story story) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BookVoiceChatSheet(story: story),
  );
}

/// Builds the agent's system prompt: instructions plus the full text of every
/// page, so the LLM can answer about the book without any retrieval.
String buildBookSystemPrompt(Story story) {
  final buf = StringBuffer()
    ..writeln(
      'You are a warm, playful companion helping a reader talk about a '
      'storybook they just read. Speak in short, natural spoken sentences '
      '(usually 1-3 at a time), as if chatting aloud. Use ONLY the story below '
      'as your source of truth about its plot, characters, and details; if '
      'asked about something not in it, say so kindly — you may imagine gently '
      'if invited. Do not read the whole story back unless asked.',
    )
    ..writeln()
    ..writeln('=== STORYBOOK: "${story.title}" ===');
  if (story.pages.isEmpty) {
    buf.writeln('(This story has no pages yet.)');
  } else {
    for (var i = 0; i < story.pages.length; i++) {
      final text = story.pages[i].text.trim();
      if (text.isEmpty) continue;
      buf.writeln('Page ${i + 1}: $text');
    }
  }
  buf.writeln('=== END OF STORYBOOK ===');
  return buf.toString();
}

class _BookVoiceChatSheet extends StatefulWidget {
  const _BookVoiceChatSheet({required this.story});

  final Story story;

  @override
  State<_BookVoiceChatSheet> createState() => _BookVoiceChatSheetState();
}

class _BookVoiceChatSheetState extends State<_BookVoiceChatSheet> {
  late final VoiceAgentController _agent;
  final ScrollController _scroll = ScrollController();
  int _lastTurnCount = 0;

  @override
  void initState() {
    super.initState();
    _agent = VoiceAgentController();
    // Defer connect so getUserMedia runs after the sheet's open gesture frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _agent.connect(
        systemPrompt: buildBookSystemPrompt(widget.story),
        greeting:
            'Hi! I just read "${widget.story.title}" with you. '
            'What would you like to talk about?',
      );
    });
  }

  @override
  void dispose() {
    _agent.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _maybeAutoScroll() {
    if (_agent.transcript.length == _lastTurnCount) return;
    _lastTurnCount = _agent.transcript.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(top: mq.padding.top + 12),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [MagicColors.nightTop, MagicColors.nightBottom],
            ),
            border: Border(
              top: BorderSide(
                color: MagicColors.lilac.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListenableBuilder(
              listenable: _agent,
              builder: (context, _) {
                _maybeAutoScroll();
                return Column(
                  children: [
                    _header(context),
                    if (!_agent.hasKey)
                      const _Banner(
                        icon: Icons.key_off,
                        message:
                            'DEEPGRAM_KEY missing. Add it to dream_book/.env '
                            'and restart.',
                      )
                    else if (_agent.error != null)
                      _Banner(icon: Icons.error_outline, message: _agent.error!),
                    _StatusOrb(phase: _agent.phase),
                    Expanded(child: _transcriptView()),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
      child: Row(
        children: [
          const Icon(Icons.graphic_eq, color: MagicColors.gold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Talk about this book',
                  style: AppTheme.displayFont(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: MagicColors.textPrimary,
                  ),
                ),
                Text(
                  widget.story.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyFont(
                    fontSize: 13,
                    color: MagicColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'End chat',
            icon: const Icon(Icons.close, color: MagicColors.textPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _transcriptView() {
    final turns = _agent.transcript;
    if (turns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _agent.phase == VoiceAgentPhase.connecting
                ? 'Warming up the storyteller…'
                : 'Say hello, then ask anything about the story.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyFont(
              fontSize: 15,
              color: MagicColors.textMuted,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: turns.length,
      itemBuilder: (context, i) => _Bubble(turn: turns[i]),
    );
  }
}

/// Animated state indicator: a pulsing orb whose color and label track the
/// conversation [phase].
class _StatusOrb extends StatelessWidget {
  const _StatusOrb({required this.phase});

  final VoiceAgentPhase phase;

  ({Color color, IconData icon, String label}) get _style {
    switch (phase) {
      case VoiceAgentPhase.connecting:
        return (
          color: MagicColors.lilac,
          icon: Icons.hourglass_top,
          label: 'Connecting…',
        );
      case VoiceAgentPhase.listening:
        return (
          color: MagicColors.gold,
          icon: Icons.mic,
          label: 'Listening — go ahead',
        );
      case VoiceAgentPhase.thinking:
        return (
          color: MagicColors.lilac,
          icon: Icons.auto_awesome,
          label: 'Thinking…',
        );
      case VoiceAgentPhase.speaking:
        return (
          color: MagicColors.gold,
          icon: Icons.graphic_eq,
          label: 'Speaking…',
        );
      case VoiceAgentPhase.error:
        return (
          color: MagicColors.danger,
          icon: Icons.error_outline,
          label: 'Something went wrong',
        );
      case VoiceAgentPhase.idle:
        return (
          color: MagicColors.textMuted,
          icon: Icons.mic_off,
          label: 'Chat ended',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    final active =
        phase == VoiceAgentPhase.listening ||
        phase == VoiceAgentPhase.speaking ||
        phase == VoiceAgentPhase.thinking;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: active ? 1.0 : 0.9),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.color.withValues(alpha: 0.16),
                border: Border.all(color: s.color.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: s.color.withValues(alpha: active ? 0.45 : 0.2),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: phase == VoiceAgentPhase.connecting
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: MagicColors.lilac,
                      ),
                    )
                  : Icon(s.icon, color: s.color, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.label,
            style: AppTheme.bodyFont(
              fontSize: 13,
              color: MagicColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single transcript line, sided and tinted by speaker.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});

  final VoiceTurn turn;

  @override
  Widget build(BuildContext context) {
    final isUser = turn.isUser;
    final bg = isUser
        ? MagicColors.gold.withValues(alpha: 0.18)
        : MagicColors.lilac.withValues(alpha: 0.16);
    final border = (isUser ? MagicColors.gold : MagicColors.lilac).withValues(
      alpha: 0.4,
    );
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(color: border),
        ),
        child: Text(
          turn.text,
          style: AppTheme.bodyFont(
            fontSize: 15,
            color: MagicColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MagicColors.danger.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MagicColors.danger.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: MagicColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodyFont(
                fontSize: 13,
                color: MagicColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
