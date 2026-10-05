import 'package:ai_remote/core/app_controller.dart';
import 'package:flutter/material.dart';

class TunerView extends StatelessWidget {
  const TunerView({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final pitch = controller.currentPitch;
    final cents = pitch?.cents ?? 0;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.tune_rounded, color: Color(0xFF63E6BE), size: 42),
          const SizedBox(height: 12),
          const Text(
            'TUNER',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Microfono in ascolto · guarda anche l’orologio',
            style: TextStyle(color: Color(0xFF91A3BB)),
          ),
          const Spacer(),
          Text(
            pitch?.note ?? '—',
            key: const Key('tunerNote'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 112,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pitch == null
                ? 'Suona una nota'
                : '${pitch.frequency.toStringAsFixed(1)} Hz  ${pitch.signedCents}',
            style: const TextStyle(
              color: Color(0xFF63E6BE),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 26),
          LinearProgressIndicator(
            value: ((cents + 50) / 100).clamp(0.0, 1.0),
            minHeight: 14,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: const Color(0xFF24344C),
            color: cents.abs() <= 5
                ? const Color(0xFF63E6BE)
                : const Color(0xFFFFC857),
          ),
          const SizedBox(height: 9),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('−50¢', style: TextStyle(color: Color(0xFF91A3BB))),
              Text(
                'CENTRATO',
                style: TextStyle(color: Color(0xFF91A3BB), fontSize: 11),
              ),
              Text('+50¢', style: TextStyle(color: Color(0xFF91A3BB))),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: controller.stopTuner,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('FERMA ACCORDATORE'),
          ),
        ],
      ),
    );
  }
}
