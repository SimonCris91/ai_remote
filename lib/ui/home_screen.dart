import 'package:ai_remote/core/app_controller.dart';
import 'package:ai_remote/core/models/channel_type.dart';
import 'package:ai_remote/core/models/remote_command.dart';
import 'package:ai_remote/core/state/ai_remote_state.dart';
import 'package:ai_remote/remote/remote_controller.dart';
import 'package:ai_remote/ui/widgets/conversation_panel.dart';
import 'package:ai_remote/ui/widgets/chord_monitor_card.dart';
import 'package:ai_remote/ui/widgets/live_chord_view.dart';
import 'package:ai_remote/ui/widgets/tuner_view.dart';
import 'package:ai_remote/ui/widgets/state_badge.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final channel = controller.selectedChannel;
        final liveChordMode = controller.isChordMonitorActive;
        final tunerMode = controller.isTunerActive;
        if (tunerMode) {
          return Scaffold(
            backgroundColor: const Color(0xFF07101D),
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.2, -0.8),
                  radius: 1.25,
                  colors: [Color(0xFF18345A), Color(0xFF07101D)],
                ),
              ),
              child: SafeArea(child: TunerView(controller: controller)),
            ),
          );
        }
        if (liveChordMode) {
          return Scaffold(
            backgroundColor: const Color(0xFF07101D),
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.2, -0.8),
                  radius: 1.25,
                  colors: [Color(0xFF18345A), Color(0xFF07101D)],
                ),
              ),
              child: SafeArea(child: LiveChordView(controller: controller)),
            ),
          );
        }
        return Scaffold(
          backgroundColor: const Color(0xFF07101D),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.2, -0.8),
                radius: 1.25,
                colors: [Color(0xFF18345A), Color(0xFF07101D)],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                child: Column(
                  children: [
                    _Header(
                      controller: controller,
                      onCreateChat: () => _createChat(context, controller),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StateBadge(state: controller.state),
                        if (controller.remoteAdapterName != null)
                          _RemoteConnectionBadge(
                            state: controller.remoteConnectionState,
                          ),
                      ],
                    ),
                    if (controller.googleSignInAvailable) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        key: const Key('googleSignInButton'),
                        onPressed: () async {
                          try {
                            if (controller.isGoogleSignedIn) {
                              await controller.signOutGoogle();
                            } else {
                              await controller.signInWithGoogle();
                            }
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Accesso Google non riuscito: $error',
                                ),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          controller.isGoogleSignedIn
                              ? Icons.verified_user_outlined
                              : Icons.account_circle_outlined,
                        ),
                        label: Text(
                          controller.isGoogleSignedIn
                              ? 'OPENAI COLLEGATO · ${controller.googleDisplayName ?? 'Google'} · DISCONNETTI'
                              : 'COLLEGA CON GOOGLE PER ATTIVARE OPENAI',
                        ),
                      ),
                    ],
                    if (controller.pairingAvailable) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        key: const Key('pairingButton'),
                        onPressed: () async {
                          if (controller.isPairingSignedIn) {
                            await controller.signOutPairing();
                            return;
                          }
                          final code = await _requestPairingCode(context);
                          if (code == null || !context.mounted) return;
                          try {
                            await controller.pairWithBackend(code);
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Abbinamento non riuscito: $error',
                                ),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          controller.isPairingSignedIn
                              ? Icons.verified_user_outlined
                              : Icons.link_rounded,
                        ),
                        label: Text(
                          controller.isPairingSignedIn
                              ? 'AI REMOTE COLLEGATO · DISCONNETTI'
                              : 'COLLEGA AI REMOTE',
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _ChannelCard(
                      channelName: liveChordMode
                          ? 'LIVE CHORD MONITOR'
                          : channel.name,
                      channelType: channel.type,
                      description: liveChordMode
                          ? 'Accordi in tempo reale · aggiornamento automatico'
                          : channel.description,
                      position: controller.channelManager.selectedIndex + 1,
                      total: controller.channelManager.channels.length,
                      isActive:
                          liveChordMode || controller.selectedChannelIsActive,
                      isLiveMode: liveChordMode,
                    ),
                    const SizedBox(height: 14),
                    ChordMonitorCard(controller: controller),
                    if (!liveChordMode &&
                        channel.type == ChannelType.translator) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        key: const Key('reverseTranslationDirection'),
                        onPressed: controller.reverseTranslationDirection,
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: Text(controller.translationDirection.label),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (!liveChordMode)
                      ConversationPanel(session: controller.selectedSession),
                    if (controller.state == AiRemoteState.error) ...[
                      const SizedBox(height: 12),
                      _ErrorPanel(
                        message:
                            controller.errorMessage ?? 'Errore sconosciuto',
                        onReset: controller.cancelCurrentInteraction,
                      ),
                    ],
                    const SizedBox(height: 26),
                    _RemoteControls(controller: controller),
                    const SizedBox(height: 18),
                    _InteractionHint(controller: controller),
                    if (controller.remoteAdapterName != null) ...[
                      const SizedBox(height: 18),
                      _WatchHelpCard(
                        connectionState: controller.remoteConnectionState,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _requestPairingCode(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (_) => const _PairingCodeDialog(),
    );
  }

  Future<_NewChatDraft?> _requestNewChat(BuildContext context) {
    return showDialog<_NewChatDraft>(
      context: context,
      builder: (_) => const _NewChatDialog(),
    );
  }

  Future<void> _createChat(
    BuildContext context,
    AppController controller,
  ) async {
    final draft = await _requestNewChat(context);
    if (draft == null || !context.mounted) return;
    try {
      await controller.channelManager.createChat(
        draft.name,
        instructions: draft.instructions,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Chat non creata: $error')));
    }
  }
}

class _NewChatDraft {
  const _NewChatDraft(this.name, this.instructions);

  final String name;
  final String instructions;
}

class _NewChatDialog extends StatefulWidget {
  const _NewChatDialog();

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  final _nameController = TextEditingController();
  final _instructionsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crea una chat'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome chat',
                hintText: 'Es. Attività giornaliera',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instructionsController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Istruzioni (facoltative)',
                hintText: 'Come deve comportarsi questa chat?',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ANNULLA'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(
              context,
            ).pop(_NewChatDraft(name, _instructionsController.text.trim()));
          },
          child: const Text('CREA'),
        ),
      ],
    );
  }
}

class _PairingCodeDialog extends StatefulWidget {
  const _PairingCodeDialog();

  @override
  State<_PairingCodeDialog> createState() => _PairingCodeDialogState();
}

class _PairingCodeDialogState extends State<_PairingCodeDialog> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Collega AI Remote'),
      content: TextField(
        controller: _codeController,
        autofocus: true,
        obscureText: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Codice di abbinamento',
          hintText: 'Inserisci il codice del tuo backend',
        ),
        onSubmitted: (_) => Navigator.of(context).pop(_codeController.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ANNULLA'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_codeController.text),
          child: const Text('COLLEGA'),
        ),
      ],
    );
  }
}

class _RemoteConnectionBadge extends StatelessWidget {
  const _RemoteConnectionBadge({required this.state});

  final RemoteConnectionState state;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (state) {
      RemoteConnectionState.connected => (
        'MEDIA READY',
        const Color(0xFF63E6BE),
        Icons.watch_outlined,
      ),
      RemoteConnectionState.connecting => (
        'MEDIA…',
        const Color(0xFFFFC857),
        Icons.sync_rounded,
      ),
      RemoteConnectionState.error => (
        'MEDIA ERROR',
        const Color(0xFFFF6B6B),
        Icons.watch_off_outlined,
      ),
      RemoteConnectionState.unavailable => (
        'MEDIA OFF',
        const Color(0xFF93A4BC),
        Icons.watch_off_outlined,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchHelpCard extends StatelessWidget {
  const _WatchHelpCard({required this.connectionState});

  final RemoteConnectionState connectionState;

  @override
  Widget build(BuildContext context) {
    final ready = connectionState == RemoteConnectionState.connected;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101827).withValues(alpha: 0.72),
        border: Border.all(color: const Color(0xFF24344C)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.watch_rounded,
            color: ready ? const Color(0xFF63E6BE) : const Color(0xFF93A4BC),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BIP U PRO · APRI “MUSICA”',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '⏮/⏭ cambia canale · ▶ ascolta · ⏸ invia il turno',
                  style: TextStyle(
                    color: Color(0xFF91A3BB),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onCreateChat});

  final AppController controller;
  final VoidCallback onCreateChat;

  @override
  Widget build(BuildContext context) {
    final badgeColor = controller.isMockMode
        ? const Color(0xFF9BB8FF)
        : const Color(0xFF63E6BE);
    return Row(
      children: [
        IconButton(
          key: const Key('createChatButton'),
          onPressed: onCreateChat,
          tooltip: 'Nuova chat',
          icon: const Icon(Icons.add_comment_outlined),
          color: const Color(0xFF63E6BE),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF63E6BE).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.waves_rounded, color: Color(0xFF63E6BE)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI REMOTE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              Text(
                'VOICE-FIRST CONTROLLER',
                style: TextStyle(
                  color: Color(0xFF8395AE),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.science_outlined, size: 13, color: badgeColor),
              const SizedBox(width: 5),
              Text(
                controller.isMockMode ? 'MOCK' : 'OPENAI',
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.channelName,
    required this.channelType,
    required this.description,
    required this.position,
    required this.total,
    required this.isActive,
    this.isLiveMode = false,
  });

  final String channelName;
  final ChannelType channelType;
  final String description;
  final int position;
  final int total;
  final bool isActive;
  final bool isLiveMode;

  @override
  Widget build(BuildContext context) {
    final icon = isLiveMode
        ? Icons.music_note_rounded
        : switch (channelType) {
            ChannelType.chat => Icons.chat_bubble_outline_rounded,
            ChannelType.translator => Icons.translate_rounded,
            ChannelType.agent => Icons.engineering_outlined,
          };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF111D2E).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isActive
              ? const Color(0xFF63E6BE).withValues(alpha: 0.65)
              : const Color(0xFF2A3D58),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isLiveMode ? 'LIVE MODE' : 'CHANNEL $position / $total',
                style: const TextStyle(
                  color: Color(0xFF73859E),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              Text(
                isLiveMode ? 'LIVE AUDIO' : channelType.label,
                style: const TextStyle(
                  color: Color(0xFF63E6BE),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Icon(icon, size: 34, color: const Color(0xFF8EABFF)),
          const SizedBox(height: 12),
          Text(
            channelName.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF9BACC2), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _RemoteControls extends StatelessWidget {
  const _RemoteControls({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(
          key: const Key('previousButton'),
          icon: Icons.skip_previous_rounded,
          tooltip: controller.isChordMonitorActive
              ? 'Accordi più lenti'
              : 'Canale precedente',
          onTap: () => controller.handleRemoteCommand(RemoteCommand.previous),
        ),
        Semantics(
          button: true,
          label: controller.isChordMonitorActive
              ? 'Ferma Live Chord Monitor'
              : 'Tieni premuto per parlare',
          child: GestureDetector(
            key: const Key('playButton'),
            onTap: controller.isChordMonitorActive
                ? controller.stopChordMonitor
                : controller.activateSelected,
            onLongPressStart: controller.isChordMonitorActive
                ? null
                : (_) => controller.startPushToTalk(),
            onLongPressEnd: controller.isChordMonitorActive
                ? null
                : (_) => controller.finishPushToTalk(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: controller.state == AiRemoteState.listening
                    ? const Color(0xFF63E6BE)
                    : const Color(0xFFEEF4FF),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6F9DFF).withValues(alpha: 0.35),
                    blurRadius: 26,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Icon(
                controller.isChordMonitorActive
                    ? Icons.stop_rounded
                    : controller.state == AiRemoteState.listening
                    ? Icons.mic_rounded
                    : Icons.play_arrow_rounded,
                size: 43,
                color: const Color(0xFF10213B),
              ),
            ),
          ),
        ),
        _RoundButton(
          key: const Key('nextButton'),
          icon: Icons.skip_next_rounded,
          tooltip: controller.isChordMonitorActive
              ? 'Accordi più veloci'
              : 'Canale successivo',
          onTap: () => controller.handleRemoteCommand(RemoteCommand.next),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Icon(icon, size: 34),
      tooltip: tooltip,
      color: const Color(0xFFD7E4F7),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF19283C),
        minimumSize: const Size(64, 64),
      ),
    );
  }
}

class _InteractionHint extends StatelessWidget {
  const _InteractionHint({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final text = controller.isChordMonitorActive
        ? '⏮ più lento · ⏭ più veloce · ▶ ferma il monitor'
        : switch (state) {
            AiRemoteState.listening => 'Rilascia il pulsante per inviare',
            AiRemoteState.processing => 'Sto preparando la risposta…',
            AiRemoteState.translating => 'Traduzione in corso…',
            AiRemoteState.aiSpeaking => 'Risposta audio in riproduzione…',
            _ => 'Tocca ▶ per attivare · tieni premuto per parlare',
          };
    final busy = {
      AiRemoteState.listening,
      AiRemoteState.processing,
      AiRemoteState.translating,
      AiRemoteState.aiSpeaking,
    }.contains(state);
    return Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF91A3BB), fontSize: 12),
        ),
        if (busy) ...[
          const SizedBox(height: 8),
          TextButton(
            key: const Key('stopButton'),
            onPressed: controller.cancelCurrentInteraction,
            child: const Text('STOP'),
          ),
        ],
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onReset});

  final String message;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x33FF6B6B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x66FF6B6B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF8A8A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white)),
          ),
          TextButton(onPressed: onReset, child: const Text('RIPROVA')),
        ],
      ),
    );
  }
}
