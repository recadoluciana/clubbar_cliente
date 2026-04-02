import 'package:flutter/material.dart';

class CadastroScreen extends StatelessWidget {
  const CadastroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastre-se')),
      body: const Center(child: Text('Tela de cadastro - próxima etapa')),
    );
  }
}
