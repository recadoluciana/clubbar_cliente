import 'package:flutter/material.dart';

class MainNavigationController {
  static final ValueNotifier<Widget?> telaInterna = ValueNotifier(null);

  static void abrirTela(Widget tela) {
    telaInterna.value = tela;
  }

  static void fecharTelaInterna() {
    telaInterna.value = null;
  }
}
