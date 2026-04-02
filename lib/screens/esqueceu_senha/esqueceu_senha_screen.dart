import 'package:flutter/material.dart';

class EsqueceuSenhaScreen extends StatelessWidget {
  const EsqueceuSenhaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: const Center(
        child: Text('Tela de recuperação de senha - próxima etapa'),
      ),
    );
  }
}
