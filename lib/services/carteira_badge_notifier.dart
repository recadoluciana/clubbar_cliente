import 'package:flutter/foundation.dart';

class CarteiraBadgeNotifier {
  static final ValueNotifier<int> refresh = ValueNotifier<int>(0);
  static final ValueNotifier<int> itensDaLojaSelecionada = ValueNotifier<int>(
    0,
  );

  static void atualizar() {
    refresh.value++;
  }

  static void atualizarItensDaLojaSelecionada(int quantidade) {
    itensDaLojaSelecionada.value = quantidade < 0 ? 0 : quantidade;
  }
}
