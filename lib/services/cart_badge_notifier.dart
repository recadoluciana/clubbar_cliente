// lib/services/cart_badge_notifier.dart
import 'package:flutter/foundation.dart';

class CartBadgeNotifier {
  static final ValueNotifier<int> totalItens = ValueNotifier<int>(0);

  static void atualizar(int total) {
    totalItens.value = total;
  }

  static void limpar() {
    totalItens.value = 0;
  }
}
