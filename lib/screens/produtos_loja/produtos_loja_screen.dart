import 'package:flutter/material.dart';
import '../../models/loja.dart';

class ProdutosLojaScreen extends StatelessWidget {
  final Loja loja;

  const ProdutosLojaScreen({super.key, required this.loja});

  @override
  Widget build(BuildContext context) {
    final categorias = ['Cervejas', 'Drinks', 'Refrigerantes', 'Porções'];

    return Scaffold(
      appBar: AppBar(title: Text('Produtos - ${loja.nome}')),
      backgroundColor: const Color(0xFFF6F6F6),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Categorias',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...categorias.map(
            (categoria) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                elevation: 1,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Lista de produtos da categoria "$categoria" será a próxima etapa',
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Icon(Icons.label_outline_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            categoria,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
