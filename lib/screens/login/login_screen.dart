import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../cadastro/cadastro_screen.dart';
import '../esqueceu_senha/esqueceu_senha_screen.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../services/main_navigation_controller.dart';
import '../main/main_navigation_screen.dart';
import '../../utils/app_snackbar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  final apiService = ApiService();
  final authStorage = AuthStorage();

  bool carregando = false;
  bool obscureSenha = true;
  bool corujaOlhoFechado = false;

  Timer? _timerCoruja;

  @override
  void initState() {
    super.initState();

    _timerCoruja = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        corujaOlhoFechado = true;
      });

      Future.delayed(const Duration(milliseconds: 180), () {
        if (!mounted) return;

        setState(() {
          corujaOlhoFechado = false;
        });
      });
    });
  }

  @override
  void dispose() {
    _timerCoruja?.cancel();
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  String traduzirErro(String erro) {
    final msg = erro.toLowerCase();

    if (msg.contains('invalid credentials')) {
      return 'E-mail ou senha inválidos.Verifique e tente novamente.';
    }

    if (msg.contains('senha')) {
      return 'Senha inválida. Verifique e tente novamente.';
    }

    if (msg.contains('email') || msg.contains('e-mail')) {
      return 'E-mail inválido. Verifique e tente novamente.';
    }

    if (msg.contains('connection') ||
        msg.contains('socket') ||
        msg.contains('failed host lookup')) {
      return 'Erro de conexão com o servidor.';
    }

    return 'Não foi possível fazer login. Tente novamente.';
  }

  Future<void> fazerLogin() async {
    final email = emailController.text.trim();
    final senha = senhaController.text;

    if (email.isEmpty) {
      AppSnackBar.erro(context, 'Informe o e-mail para realizar o login.');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      AppSnackBar.erro(context, 'Informe um e-mail válido.');
      return;
    }

    if (senha.isEmpty) {
      AppSnackBar.erro(context, 'Informe a senha para realizar o login.');
      return;
    }

    if (senha.length < 6) {
      AppSnackBar.erro(context, 'A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final response = await apiService.login(email: email, senha: senha);

      await authStorage.salvarLogin(
        token: response.accessToken,
        clienteId: response.clienteId ?? 0,
        nomeCliente: response.nmcliente ?? '',
      );

      if (!mounted) return;

      AppSnackBar.sucesso(context, 'Login realizado com sucesso!');

      MainNavigationController.irParaHome();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, traduzirErro(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  InputDecoration campoDecoracao({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.amber, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: ClubbarAppBar(
        mostrarVoltar: true,
        onVoltar: () {
          MainNavigationController.irParaHome();
          Navigator.of(context).maybePop();
        },
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(color: Color(0xFFF7F7F7)),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  children: [
                    Image.asset(
                      corujaOlhoFechado
                          ? 'assets/images/corujao_piscando.png'
                          : 'assets/images/corujao.png',
                      height: 100,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.16),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: campoDecoracao(
                                label: 'E-mail',
                                icon: Icons.email_outlined,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: senhaController,
                              obscureText: obscureSenha,
                              decoration: campoDecoracao(
                                label: 'Senha',
                                icon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      obscureSenha = !obscureSenha;
                                    });
                                  },
                                  icon: Icon(
                                    obscureSenha
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => fazerLogin(),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: carregando ? null : fazerLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: carregando
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.6,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.black,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Entrar',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    final ok = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CadastroClienteScreen(),
                                      ),
                                    );

                                    if (!context.mounted) return;
                                    if (ok == true) {
                                      AppSnackBar.aviso(
                                        context,
                                        'Agora faça login para continuar.',
                                      );
                                    }
                                  },
                                  child: const Text('Cadastre-se aqui'),
                                ),
                                const Text(' | '),
                                TextButton(
                                  onPressed: carregando
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const EsqueceuSenhaScreen(),
                                            ),
                                          );
                                        },
                                  child: const Text('Esqueceu a senha?'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Ao continuar você concorda com os termos de uso do app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
