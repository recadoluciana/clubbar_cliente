import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class MercadoPagoBrickScreen extends StatelessWidget {
  const MercadoPagoBrickScreen({
    super.key,
    required this.publicKey,
    required this.amount,
    this.tempoReserva,
  });
  final String publicKey;
  final double amount;
  final ValueListenable<Duration>? tempoReserva;
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Pagamento indisponível nesta plataforma.')),
  );
}
