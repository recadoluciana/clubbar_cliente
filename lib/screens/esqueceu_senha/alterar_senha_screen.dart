import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class AlterarSenhaScreen extends StatefulWidget {
  const AlterarSenhaScreen({super.key});

  @override
  State<AlterarSenhaScreen> createState() => _AlterarSenhaScreenState();
}

class _AlterarSenhaScreenState extends State<AlterarSenhaScreen> {
  final _formKey = GlobalKey<FormState>();

  final _senhaAtualCtrl = TextEditingController();
  final _novaSenhaCtrl = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();

  final apiService = ApiService();

  bool carregando = false;
  bool ocultarSenhaAtual = true;
  bool ocultarNovaSenha = true;
  bool ocultarConfirmarSenha = true;

  @override
  void dispose() {
    _senhaAtualCtrl.dispose();
    _novaSenhaCtrl.dispose();
    _confirmarSenhaCtrl.dispose();
    super.dispose();
  }

  Future<void> salvarNovaSenha() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      carregando = true;
    });

    try {
      await apiService.alterarMinhaSenha(
        senhaAtual: _senhaAtualCtrl.text.trim(),
        novaSenha: _novaSenhaCtrl.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha alterada com sucesso')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  InputDecoration _decoracao({
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(title: const Text('Alterar senha')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Atualize sua senha',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Informe sua senha atual e depois escolha uma nova senha para sua conta.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _senhaAtualCtrl,
                obscureText: ocultarSenhaAtual,
                decoration: _decoracao(
                  label: 'Senha atual',
                  icon: Icons.lock_outline,
                  obscure: ocultarSenhaAtual,
                  onToggle: () {
                    setState(() {
                      ocultarSenhaAtual = !ocultarSenhaAtual;
                    });
                  },
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Informe sua senha atual';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _novaSenhaCtrl,
                obscureText: ocultarNovaSenha,
                decoration: _decoracao(
                  label: 'Nova senha',
                  icon: Icons.lock_reset_outlined,
                  obscure: ocultarNovaSenha,
                  onToggle: () {
                    setState(() {
                      ocultarNovaSenha = !ocultarNovaSenha;
                    });
                  },
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Informe a nova senha';
                  if (v.length < 6) {
                    return 'A nova senha deve ter pelo menos 6 caracteres';
                  }
                  if (v == _senhaAtualCtrl.text.trim()) {
                    return 'A nova senha deve ser diferente da atual';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _confirmarSenhaCtrl,
                obscureText: ocultarConfirmarSenha,
                decoration: _decoracao(
                  label: 'Confirmar nova senha',
                  icon: Icons.lock_person_outlined,
                  obscure: ocultarConfirmarSenha,
                  onToggle: () {
                    setState(() {
                      ocultarConfirmarSenha = !ocultarConfirmarSenha;
                    });
                  },
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Confirme a nova senha';
                  if (v != _novaSenhaCtrl.text.trim()) {
                    return 'As senhas não conferem';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: carregando ? null : salvarNovaSenha,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: carregando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Salvar nova senha',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
