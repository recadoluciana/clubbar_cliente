import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/clubbar_page_header.dart';

class RedefinirSenhaScreen extends StatefulWidget {
  final String email;

  const RedefinirSenhaScreen({super.key, required this.email});

  @override
  State<RedefinirSenhaScreen> createState() => _RedefinirSenhaScreenState();
}

class _RedefinirSenhaScreenState extends State<RedefinirSenhaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();
  final apiService = ApiService();

  bool carregando = false;
  bool obscureSenha = true;
  bool obscureConfirmarSenha = true;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmarSenhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _redefinir() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => carregando = true);

    try {
      await apiService.redefinirSenha(
        email: widget.email,
        codigo: _codigoCtrl.text.trim(),
        novaSenha: _senhaCtrl.text,
      );

      if (!mounted) return;
      AppSnackBar.sucesso(context, 'Senha redefinida com sucesso.');
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(context, apiService.mensagemErroAmigavel(e));
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  InputDecoration _decoracao({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
    String? hint,
  }) {
    final normal = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    final erro = normal.copyWith(
      borderSide: BorderSide(color: Colors.red.shade700),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: normal,
      enabledBorder: normal,
      focusedBorder: normal.copyWith(
        borderSide: const BorderSide(color: Colors.amber, width: 1.6),
      ),
      errorBorder: erro,
      focusedErrorBorder: erro,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: SafeArea(
        child: Column(
          children: [
            const ClubbarPageHeader(
              titulo: 'Criar nova senha',
              subtitulo: 'Digite o código recebido e escolha uma nova senha',
              icone: Icons.password_rounded,
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: .35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.alternate_email_rounded,
                            color: Color(0xFF7A5A00),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Código enviado para',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6A5200),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.email,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _codigoCtrl,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6,
                            ),
                            decoration: _decoracao(
                              label: 'Código de 6 dígitos',
                              icon: Icons.verified_user_outlined,
                              hint: '000000',
                            ),
                            validator: (value) {
                              final codigo = value?.trim() ?? '';
                              if (codigo.isEmpty) return 'Informe o código';
                              if (codigo.length != 6) {
                                return 'O código deve conter 6 dígitos';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _senhaCtrl,
                            obscureText: obscureSenha,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: _decoracao(
                              label: 'Nova senha',
                              icon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                tooltip: obscureSenha
                                    ? 'Mostrar senha'
                                    : 'Ocultar senha',
                                onPressed: () => setState(
                                  () => obscureSenha = !obscureSenha,
                                ),
                                icon: Icon(
                                  obscureSenha
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final senha = value ?? '';
                              if (senha.isEmpty) return 'Informe a nova senha';
                              if (senha.length < 6) {
                                return 'A senha deve ter pelo menos 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirmarSenhaCtrl,
                            obscureText: obscureConfirmarSenha,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            onFieldSubmitted: (_) {
                              if (!carregando) _redefinir();
                            },
                            decoration: _decoracao(
                              label: 'Confirmar nova senha',
                              icon: Icons.lock_reset_rounded,
                              suffixIcon: IconButton(
                                tooltip: obscureConfirmarSenha
                                    ? 'Mostrar senha'
                                    : 'Ocultar senha',
                                onPressed: () => setState(
                                  () => obscureConfirmarSenha =
                                      !obscureConfirmarSenha,
                                ),
                                icon: Icon(
                                  obscureConfirmarSenha
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final confirmacao = value ?? '';
                              if (confirmacao.isEmpty) {
                                return 'Confirme a nova senha';
                              }
                              if (confirmacao != _senhaCtrl.text) {
                                return 'As senhas não conferem';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: Colors.black54,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Use pelo menos 6 caracteres. O código expira em 15 minutos.',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: carregando ? null : _redefinir,
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
                                carregando
                                    ? 'Salvando...'
                                    : 'Salvar nova senha',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                                disabledBackgroundColor: Colors.amber
                                    .withValues(alpha: .55),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
