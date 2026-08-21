import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/clubbar_page_header.dart';

class AlterarSenhaScreen extends StatefulWidget {
  final VoidCallback onVoltar;

  const AlterarSenhaScreen({super.key, required this.onVoltar});

  @override
  State<AlterarSenhaScreen> createState() => _AlterarSenhaScreenState();
}

class _AlterarSenhaScreenState extends State<AlterarSenhaScreen> {
  final _formKey = GlobalKey<FormState>();

  final _senhaAtualCtrl = TextEditingController();
  final _novaSenhaCtrl = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();

  final apiService = ApiService();
  final authStorage = AuthStorage();

  bool carregando = false;
  bool carregandoCliente = true;

  bool ocultarSenhaAtual = true;
  bool ocultarNovaSenha = true;
  bool ocultarConfirmarSenha = true;

  String nomeCliente = '';

  @override
  void initState() {
    super.initState();
    carregarCliente();
  }

  @override
  void dispose() {
    _senhaAtualCtrl.dispose();
    _novaSenhaCtrl.dispose();
    _confirmarSenhaCtrl.dispose();
    super.dispose();
  }

  Future<void> carregarCliente() async {
    try {
      final nome = await authStorage.obterNmcliente();

      if (!mounted) return;

      setState(() {
        nomeCliente = nome?.trim() ?? '';
        carregandoCliente = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        nomeCliente = '';
        carregandoCliente = false;
      });
    }
  }

  Future<void> salvarNovaSenha() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      await apiService.alterarMinhaSenha(
        senhaAtual: _senhaAtualCtrl.text.trim(),
        novaSenha: _novaSenhaCtrl.text.trim(),
      );

      if (!mounted) return;

      AppSnackBar.sucesso(context, 'Senha alterada com sucesso.');

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, apiService.mensagemErroAmigavel(e));
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
    final bordaNormal = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
    );

    final bordaFoco = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.amber, width: 1.6),
    );

    final bordaErro = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.red.shade700, width: 1),
    );

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: IconButton(
        tooltip: obscure ? 'Mostrar senha' : 'Ocultar senha',
        onPressed: onToggle,
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: bordaNormal,
      enabledBorder: bordaNormal,
      focusedBorder: bordaFoco,
      errorBorder: bordaErro,
      focusedErrorBorder: bordaErro.copyWith(
        borderSide: BorderSide(color: Colors.red.shade700, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitulo = nomeCliente.isEmpty
        ? 'Atualize a senha da sua conta'
        : '$nomeCliente • Atualize a senha da sua conta';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: ClubbarAppBar(mostrarVoltar: true, onVoltar: widget.onVoltar),

      body: carregandoCliente
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                ClubbarPageHeader(
                  titulo: 'Alterar senha',
                  subtitulo: subtitulo,
                  icone: Icons.lock_reset_rounded,
                ),

                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.security_rounded,
                                color: Color(0xFF8A6500),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Confirme sua senha atual antes de cadastrar uma nova senha.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _senhaAtualCtrl,
                          obscureText: ocultarSenhaAtual,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.password],
                          decoration: _decoracao(
                            label: 'Senha atual',
                            icon: Icons.lock_outline_rounded,
                            obscure: ocultarSenhaAtual,
                            onToggle: () {
                              setState(() {
                                ocultarSenhaAtual = !ocultarSenhaAtual;
                              });
                            },
                          ),
                          validator: (value) {
                            final senha = value?.trim() ?? '';

                            if (senha.isEmpty) {
                              return 'Informe sua senha atual';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _novaSenhaCtrl,
                          obscureText: ocultarNovaSenha,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
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
                            final novaSenha = value?.trim() ?? '';
                            final senhaAtual = _senhaAtualCtrl.text.trim();

                            if (novaSenha.isEmpty) {
                              return 'Informe a nova senha';
                            }

                            if (novaSenha.length < 6) {
                              return 'A nova senha deve ter pelo menos 6 caracteres';
                            }

                            if (novaSenha == senhaAtual) {
                              return 'A nova senha deve ser diferente da atual';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _confirmarSenhaCtrl,
                          obscureText: ocultarConfirmarSenha,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          onFieldSubmitted: (_) {
                            if (!carregando) {
                              salvarNovaSenha();
                            }
                          },
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
                            final confirmacao = value?.trim() ?? '';
                            final novaSenha = _novaSenhaCtrl.text.trim();

                            if (confirmacao.isEmpty) {
                              return 'Confirme a nova senha';
                            }

                            if (confirmacao != novaSenha) {
                              return 'As senhas não conferem';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: .35),
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 20,
                                color: Color(0xFF7A5A00),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'A nova senha deve conter pelo menos 6 caracteres e ser diferente da senha atual.',
                                  style: TextStyle(
                                    color: Color(0xFF6A5200),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: carregando ? null : salvarNovaSenha,
                            icon: carregando
                                ? const SizedBox(
                                    width: 21,
                                    height: 21,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_outline_rounded,
                                  ),
                            label: Text(
                              carregando ? 'Salvando...' : 'Salvar nova senha',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.amber.withValues(
                                alpha: .55,
                              ),
                              disabledForegroundColor: Colors.black54,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
