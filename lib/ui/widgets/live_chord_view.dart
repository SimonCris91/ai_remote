import 'package:ai_remote/core/app_controller.dart';
import 'package:flutter/material.dart';

/// Dedicated phone view while Android playback capture is running.
class LiveChordView extends StatelessWidget {
  const LiveChordView({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final monitor = controller.chordMonitor!;
    final estimate = monitor.current;
    final nextChord = controller.predictedNextChord;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 52),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    color: Color(0xFF63E6BE),
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'LIVE CHORD MONITOR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Audio riprodotto dal telefono',
                    style: TextStyle(color: Color(0xFF91A3BB), fontSize: 13),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111D2E),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFF63E6BE)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'ACCORDO ATTUALE',
                        style: TextStyle(
                          color: Color(0xFF91A3BB),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 148,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            estimate?.label ?? '—',
                            key: const Key('liveChordLabel'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 138,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        estimate == null
                            ? 'In ascolto della musica…'
                            : 'Stima in tempo reale',
                        style: const TextStyle(
                          color: Color(0xFF63E6BE),
                          fontSize: 13,
                        ),
                      ),
                      if (controller.chordMonitorBpm != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Ritmo rilevato: ${controller.chordMonitorBpm!.round()} BPM · cambi allineati al battito',
                          style: const TextStyle(
                            color: Color(0xFF91A3BB),
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (nextChord != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Possibile prossimo: $nextChord',
                          key: const Key('predictedChord'),
                          style: const TextStyle(
                            color: Color(0xFFFFC857),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Column(
                children: [
                  Text(
                    controller.chordMonitorTimingLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF91A3BB),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Control(
                    key: const Key('stopLiveButton'),
                    icon: Icons.stop_rounded,
                    label: 'Ferma monitor',
                    prominent: true,
                    onPressed: controller.stopChordMonitor,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '⏸ ferma · il ritmo viene mantenuto automaticamente',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF91A3BB), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.prominent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(icon, size: 34),
        color: prominent ? const Color(0xFF10213B) : Colors.white,
        style: IconButton.styleFrom(
          backgroundColor: prominent
              ? const Color(0xFF63E6BE)
              : const Color(0xFF19283C),
          minimumSize: const Size(68, 68),
        ),
      ),
      const SizedBox(height: 7),
      Text(
        label,
        style: const TextStyle(color: Color(0xFF91A3BB), fontSize: 11),
      ),
    ],
  );
}
