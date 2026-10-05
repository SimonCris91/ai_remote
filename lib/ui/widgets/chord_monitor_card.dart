import 'package:ai_remote/core/app_controller.dart';
import 'package:flutter/material.dart';

class ChordMonitorCard extends StatelessWidget {
  const ChordMonitorCard({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final monitor = controller.chordMonitor;
    if (monitor == null) {
      return const SizedBox.shrink();
    }
    final estimate = monitor.current;
    final active = monitor.isRunning;
    final error = monitor.errorMessage;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF101827).withValues(alpha: 0.9),
        border: Border.all(
          color: active
              ? const Color(0xFF63E6BE).withValues(alpha: 0.65)
              : const Color(0xFF24344C),
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.music_note_rounded,
                color: active
                    ? const Color(0xFF63E6BE)
                    : const Color(0xFF8EABFF),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE CHORD MONITOR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Spotify, musica e altre app Android',
                      style: TextStyle(color: Color(0xFF91A3BB), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('tunerButton'),
                    tooltip: controller.isTunerActive
                        ? 'Ferma accordatore'
                        : 'Apri accordatore',
                    onPressed: controller.isTunerActive
                        ? controller.stopTuner
                        : controller.startTuner,
                    icon: Icon(
                      controller.isTunerActive
                          ? Icons.stop_rounded
                          : Icons.tune_rounded,
                    ),
                    color: controller.isTunerActive
                        ? const Color(0xFFFFC857)
                        : const Color(0xFF8EABFF),
                  ),
                  IconButton(
                    key: const Key('chordMonitorButton'),
                    tooltip: active ? 'Ferma analisi' : 'Avvia analisi',
                    onPressed: active
                        ? controller.stopChordMonitor
                        : controller.startChordMonitor,
                    icon: Icon(active ? Icons.stop_rounded : Icons.play_arrow),
                    color: active
                        ? const Color(0xFFFFC857)
                        : const Color(0xFF63E6BE),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  estimate?.label ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              error ??
                  (active
                      ? 'Analizzo l’audio riprodotto dal telefono…'
                      : 'Premi ▶ e autorizza Android a catturare l’audio di sistema.'),
              style: TextStyle(
                color: error == null
                    ? const Color(0xFF91A3BB)
                    : const Color(0xFFFF8A8A),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
          if (active) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${controller.chordMonitorTimingLabel} · ${controller.chordMonitorBpm == null ? 'ritmo in rilevamento' : 'ritmo stabile ${controller.chordMonitorBpm!.round()} BPM'}',
                style: const TextStyle(
                  color: Color(0xFF63E6BE),
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
