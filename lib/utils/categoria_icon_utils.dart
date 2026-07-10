import 'package:flutter/material.dart';

class CategoriaIconUtils {
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
