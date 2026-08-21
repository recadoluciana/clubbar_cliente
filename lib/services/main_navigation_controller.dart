import 'package:flutter/material.dart';

class MainNavigationController {
  static final ValueNotifier<Widget?> telaInterna = ValueNotifier(null);
  static final ValueNotifier<int> abaIndex = ValueNotifier(0);
  static final List<Widget> _historico = [];

  static void abrirTela(Widget tela) {
    final atual = telaInterna.value;
    if (atual != null) {
      _historico.add(atual);
    }
    telaInterna.value = tela;
  }

  static void fecharTelaInterna() {
    telaInterna.value = _historico.isEmpty ? null : _historico.removeLast();
  }

  static void limparTelasInternas() {
    _historico.clear();
    telaInterna.value = null;
  }

  static void irParaHome() {
    limparTelasInternas();
    abaIndex.value = 0;
  }

  static void irParaCarrinho() {
    limparTelasInternas();
    abaIndex.value = 1;
  }
}
