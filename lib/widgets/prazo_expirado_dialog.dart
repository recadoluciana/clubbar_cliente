import 'package:flutter/material.dart';

enum PrazoExpiradoTipo { reserva, pix, estorno }

Future<void> mostrarPrazoExpirado(
  BuildContext context, {
  required PrazoExpiradoTipo tipo,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade800,
            size: 42,
          ),
          const SizedBox(height: 16),
          Text(
            tipo == PrazoExpiradoTipo.estorno
                ? 'Pagamento estornado'
                : tipo == PrazoExpiradoTipo.pix
                ? 'O prazo do Pix expirou'
                : 'O tempo para a compra expirou',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            tipo == PrazoExpiradoTipo.estorno
                ? 'A reserva expirou e o pagamento foi estornado. Consulte sua conta para acompanhar a devolução.'
                : tipo == PrazoExpiradoTipo.pix
                ? 'Este QR Code não pode mais ser usado. Se você já pagou, confira sua carteira antes de tentar novamente.'
                : 'O prazo da reserva terminou e os ingressos podem voltar a ficar disponíveis. Se você já pagou, confira sua carteira antes de tentar novamente.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('VOLTAR'),
            ),
          ),
        ],
      ),
    ),
  ),
);
