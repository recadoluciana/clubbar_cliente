import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Exibe no checkout o mesmo contador controlado pela tela da reserva.
class ReservaTempoBanner extends StatelessWidget {
  const ReservaTempoBanner({super.key, required this.tempo});

  final ValueListenable<Duration> tempo;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
    valueListenable: tempo,
    builder: (context, restante, _) {
      final segundos = restante.inSeconds < 0 ? 0 : restante.inSeconds;
      final minutos = (segundos ~/ 60).toString().padLeft(2, '0');
      final segundosFormatados = (segundos % 60).toString().padLeft(2, '0');
      final urgente = segundos <= 120;
      final cor = urgente ? Colors.red.shade700 : Colors.amber.shade900;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: urgente ? Colors.red.shade50 : Colors.amber.shade50,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.timer_outlined, color: cor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tempo restante da reserva: $minutos:$segundosFormatados',
                    style: TextStyle(color: cor, fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Conclua o pagamento dentro do prazo para manter os ingressos reservados.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
