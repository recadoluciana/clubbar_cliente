import 'package:flutter/material.dart';

class MercadoPagoBrickScreen extends StatelessWidget {
  const MercadoPagoBrickScreen({
    super.key,
    required this.publicKey,
    required this.amount,
  });
  final String publicKey;
  final double amount;
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Pagamento indisponível nesta plataforma.')),
  );
}
