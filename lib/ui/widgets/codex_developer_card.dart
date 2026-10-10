import 'package:ai_remote/core/app_controller.dart';
import 'package:flutter/material.dart';

Future<bool> confirmCodexDeveloperTurn(
  BuildContext context,
  AppController controller,
) async {
  if (!controller.codexDeveloperReady) return false;
  final approved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Autorizza un turno Codex'),
      content: const Text(
        'Per un solo turno, valido un minuto, Codex può leggere e modificare '
        'il checkout AI Remote ed eseguire i normali controlli del progetto. '
        'Accesso ad altre cartelle, rete, commit, push, deploy e installazioni '
        'non sono autorizzati da questa conferma.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('ANNULLA'),
        ),
        FilledButton(
          key: const Key('approveCodexTurn'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('AUTORIZZA 1 TURNO'),
        ),
      ],
    ),
  );
  if (approved == true && context.mounted) {
    controller.authorizeNextCodexTurn();
    return true;
  }
  return false;
}

class CodexDeveloperCard extends StatelessWidget {
  const CodexDeveloperCard({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.isCodexDeveloperChannel) return const SizedBox.shrink();
    final ready = controller.codexDeveloperReady;
    final authorized = controller.codexTurnConsentActive;
    final accent = ready ? const Color(0xFF63E6BE) : const Color(0xFFFFC857);
    return Container(
      key: const Key('codexDeveloperCard'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101827).withValues(alpha: 0.9),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terminal_rounded, color: accent),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'CODEX DEVELOPER',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (authorized)
                Icon(Icons.verified_user_rounded, color: accent, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ready
                ? authorized
                      ? 'Un turno autorizzato: usa ora PLAY sull’orologio o invia un messaggio.'
                      : 'Prima di ogni turno serve la tua conferma. Vale per un solo turno e scade dopo un minuto.'
                : controller.isMockMode
                ? 'Collega AI Remote al backend: in modalità MOCK il canale non può lavorare sui file.'
                : 'Questa build non instrada ancora il canale al runtime Codex.',
            style: const TextStyle(color: Color(0xFF91A3BB), height: 1.4),
          ),
          if (ready) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('authorizeCodexTurn'),
              onPressed: authorized || !controller.canAuthorizeCodexTurn
                  ? null
                  : () => confirmCodexDeveloperTurn(context, controller),
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(
                authorized ? 'TURNO AUTORIZZATO' : 'AUTORIZZA 1 TURNO CODEX',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
