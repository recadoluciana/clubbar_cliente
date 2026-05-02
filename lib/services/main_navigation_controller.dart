import 'package:flutter/material.dart';

class MainNavigationController {
  static final ValueNotifier<Widget?> telaInterna = ValueNotifier(null);
  static final ValueNotifier<int> abaIndex = ValueNotifier(0);

  static void abrirTela(Widget tela) {
    telaInterna.value = tela;
  }

  static void fecharTelaInterna() {
    telaInterna.value = null;
  }

  static void irParaHome() {
    telaInterna.value = null;
    abaIndex.value = 0;
  }
}
