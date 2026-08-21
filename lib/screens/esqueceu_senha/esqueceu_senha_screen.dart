import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/clubbar_page_header.dart';
import 'redefinir_senha_screen.dart';

class EsqueceuSenhaScreen extends StatefulWidget {
  const EsqueceuSenhaScreen({super.key});

  @override
  State<EsqueceuSenhaScreen> createState() => _EsqueceuSenhaScreenState();
}

class _EsqueceuSenhaScreenState extends State<EsqueceuSenhaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final apiService = ApiService();

  bool carregando = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  bool _validarEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => carregando = true);
    final email = _emailCtrl.text.trim().toLowerCase();

    try {
      await apiService.esqueceuSenha(email: email);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.mark_email_read_rounded, color: Colors.green),
              SizedBox(width: 10),
              Text('Código enviado'),
            ],
          ),
          content: Text(
            'Enviamos um código de recuperação para $email.\n\n'
            'Verifique também a pasta de spam ou lixo eletrônico.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RedefinirSenhaScreen(email: email)),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(context, apiService.mensagemErroAmigavel(e));
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  InputDecoration _decoracao() {
    final normal = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    final erro = normal.copyWith(
      borderSide: BorderSide(color: Colors.red.shade700),
    );

    return InputDecoration(
      labelText: 'E-mail da sua conta',
      hintText: 'seuemail@exemplo.com',
      prefixIcon: const Icon(Icons.alternate_email_rounded),
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
              titulo: 'Recuperar senha',
              subtitulo: 'Receba um código de segurança no seu e-mail',
              icone: Icons.lock_reset_rounded,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                color: Color(0xFF8A6500),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Informe o e-mail cadastrado',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Você receberá um código de 6 dígitos válido por 15 minutos.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            onFieldSubmitted: (_) {
                              if (!carregando) _enviar();
                            },
                            decoration: _decoracao(),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return 'Informe seu e-mail';
                              if (!_validarEmail(email)) {
                                return 'Informe um e-mail válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: carregando ? null : _enviar,
                              icon: carregando
                                  ? const SizedBox(
                                      width: 21,
                                      height: 21,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                              label: Text(
                                carregando
                                    ? 'Enviando código...'
                                    : 'Enviar código',
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
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: .18),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.security_rounded,
                            color: Colors.blue,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Por segurança, nunca informe o código recebido a outras pessoas.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
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
