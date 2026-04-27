import 'package:flutter/foundation.dart';

class CarteiraBadgeNotifier {
  static final ValueNotifier<int> refresh = ValueNotifier<int>(0);

  static void atualizar() {
    refresh.value++;
  }
}
