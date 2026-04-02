import 'package:flutter/material.dart';
import '../../models/loja.dart';
import '../../widgets/clubbar_app_bar.dart';

class DetalheLojaScreen extends StatelessWidget {
  final Loja loja;

  const DetalheLojaScreen({super.key, required this.loja});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ClubbarAppBar(showLogout: false),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Image.network(
              loja.imagemUrl,
              width: double.infinity,
              height: 240,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: double.infinity,
                height: 240,
                color: Colors.grey.shade300,
                alignment: Alignment.center,
                child: const Icon(Icons.storefront, size: 48),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loja.nome,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bairro: ${loja.bairro}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Horário: ${loja.horario}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
