import 'package:flutter/material.dart';

class CartaoWebScreen extends StatelessWidget {
  final String url;

  const CartaoWebScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento com cartão')),
      body: Column(
        children: [
          Expanded(
            child: SelectableText(url, style: const TextStyle(fontSize: 16)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton.icon(
              onPressed: () {
                // no Flutter Web, abrir em nova aba é o mais simples
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir página de pagamento'),
            ),
          ),
        ],
      ),
    );
  }
}
