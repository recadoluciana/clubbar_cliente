import 'package:flutter/material.dart';

import '../models/loja.dart';
import '../screens/carrinho/carrinho_lojas_screen.dart';
import '../screens/carrinho/carrinho_screen.dart';
import '../services/cart_badge_notifier.dart';

class CartBadgeAction extends StatelessWidget {
  final Loja? loja;

  const CartBadgeAction({
    super.key,
    this.loja,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: CartBadgeNotifier.totalItens,
      builder: (context, totalItensCarrinho, _) {
        Widget icon = const Icon(Icons.shopping_cart_outlined);

        if (totalItensCarrinho > 0) {
          icon = Badge(
            label: Text(
              totalItensCarrinho > 99 ? '99+' : '$totalItensCarrinho',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Icon(Icons.shopping_cart_outlined),
          );
        }

        return IconButton(
          tooltip: 'Carrinho',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => loja != null
                    ? CarrinhoScreen(loja: loja!)
                    : const CarrinhoLojasScreen(),
              ),
            );
          },
          icon: icon,
        );
      },
    );
  }
}