import 'package:ai_remote/core/app_controller.dart';
import 'package:ai_remote/core/state/ai_remote_state.dart';
import 'package:ai_remote/ui/widgets/codex_developer_card.dart';
import 'package:flutter/material.dart';

class TextMessageComposer extends StatefulWidget {
  const TextMessageComposer({super.key, required this.controller});

  final AppController controller;

  @override
  State<TextMessageComposer> createState() => _TextMessageComposerState();
}

class _TextMessageComposerState extends State<TextMessageComposer> {
  final _textController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _textController.text.trim().isEmpty) return;
    if (widget.controller.isCodexDeveloperChannel &&
        !widget.controller.codexTurnConsentActive) {
      final approved = await confirmCodexDeveloperTurn(
        context,
        widget.controller,
      );
      if (!approved || !mounted) return;
    }
    setState(() => _sending = true);
    try {
      final sent = await widget.controller.sendTextMessage(
        _textController.text,
      );
      if (sent && mounted) _textController.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final busy =
            _sending ||
            widget.controller.state == AiRemoteState.processing ||
            widget.controller.state == AiRemoteState.translating ||
            widget.controller.state == AiRemoteState.listening ||
            widget.controller.isChordMonitorActive ||
            widget.controller.isTunerActive;
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF101827).withValues(alpha: 0.92),
            border: Border.all(color: const Color(0xFF24344C)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('messageInput'),
                  controller: _textController,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 8000,
                  enabled: !busy,
                  style: const TextStyle(color: Color(0xFFD7E1EE)),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: 'Scrivi un messaggio…',
                    hintStyle: TextStyle(color: Color(0xFF8FA1BA)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(
                key: const Key('sendTextMessage'),
                tooltip: 'Invia messaggio',
                onPressed: busy ? null : _send,
                color: const Color(0xFF63E6BE),
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        );
      },
    );
  }
}
