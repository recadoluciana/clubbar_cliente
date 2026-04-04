import 'package:flutter/material.dart';
import '../../models/loja.dart';

class EventosLojaScreen extends StatelessWidget {
  final Loja loja;

  const EventosLojaScreen({super.key, required this.loja});

  @override
  Widget build(BuildContext context) {
    final eventos = [
      {
        'titulo': 'Show do Cleiton',
        'data': '10/10/2026',
        'lotes': ['1º lote - R\$ 30,00', '2º lote - R\$ 40,00'],
      },
      {
        'titulo': 'Men at Work',
        'data': '10/04/2026',
        'lotes': ['Lote promocional - R\$ 25,00'],
      },
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Ingressos - ${loja.nome}')),
      backgroundColor: const Color(0xFFF6F6F6),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Eventos e lotes',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...eventos.map(
            (evento) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                elevation: 1,
                child: ExpansionTile(
                  title: Text(
                    evento['titulo'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(evento['data'] as String),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    ...(evento['lotes'] as List<String>).map(
                      (lote) => Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.confirmation_number_outlined),
                            const SizedBox(width: 10),
                            Expanded(child: Text(lote)),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Compra do lote "$lote" será a próxima etapa',
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Comprar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
