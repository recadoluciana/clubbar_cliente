import 'package:flutter/material.dart';

class CategoriaIconUtils {
  static Color corPorNome(String nome) {
    final texto = nome.trim().toLowerCase();
    if (texto.contains('cerveja') || texto.contains('chopp')) return const Color(0xFFAF6B00);
    if (texto.contains('água') || texto.contains('agua')) return const Color(0xFF087BAA);
    if (texto.contains('refrigerante') || texto.contains('suco')) return const Color(0xFF23813A);
    if (texto.contains('vinho')) return const Color(0xFF8E2A5B);
    if (texto.contains('drink') || texto.contains('coquetel') || texto.contains('destilado')) return const Color(0xFF7340A0);
    if (texto.contains('pizza') || texto.contains('lanche') || texto.contains('hamburguer') || texto.contains('hambúrguer')) return const Color(0xFFCF4B22);
    if (texto.contains('sobremesa') || texto.contains('doce') || texto.contains('bolo')) return const Color(0xFFB83272);
    if (texto.contains('café') || texto.contains('cafe')) return const Color(0xFF79513A);
    if (texto.contains('energético') || texto.contains('energetico')) return const Color(0xFFB57900);
    if (texto.contains('combo')) return const Color(0xFF28609B);
    return const Color(0xFF8C5A15);
  }

  static IconData porNome(String nome) {
    final texto = nome.trim().toLowerCase();

    if (texto.contains('cerveja') ||
        texto.contains('chopp') ||
        texto.contains('alcoólica') ||
        texto.contains('alcoolica')) {
      return Icons.sports_bar_rounded;
    }

    if (texto.contains('refrigerante')) {
      return Icons.local_drink_rounded;
    }

    if (texto.contains('água') || texto.contains('agua')) {
      return Icons.water_drop_rounded;
    }

    if (texto.contains('suco')) {
      return Icons.local_cafe_rounded;
    }

    if (texto.contains('lanche') ||
        texto.contains('hambúrguer') ||
        texto.contains('hamburguer')) {
      return Icons.lunch_dining_rounded;
    }

    if (texto.contains('porção') ||
        texto.contains('porcao') ||
        texto.contains('petisco')) {
      return Icons.fastfood_rounded;
    }

    if (texto.contains('pizza')) {
      return Icons.local_pizza_rounded;
    }

    if (texto.contains('sobremesa') ||
        texto.contains('doce') ||
        texto.contains('bolo')) {
      return Icons.cake_rounded;
    }

    if (texto.contains('café') || texto.contains('cafe')) {
      return Icons.coffee_rounded;
    }

    if (texto.contains('vinho')) {
      return Icons.wine_bar_rounded;
    }

    if (texto.contains('drink') ||
        texto.contains('coquetel') ||
        texto.contains('dose') ||
        texto.contains('destilado')) {
      return Icons.local_bar_rounded;
    }

    if (texto.contains('energético') || texto.contains('energetico')) {
      return Icons.bolt_rounded;
    }

    if (texto.contains('combo')) {
      return Icons.inventory_2_rounded;
    }

    return Icons.restaurant_menu_rounded;
  }
}
