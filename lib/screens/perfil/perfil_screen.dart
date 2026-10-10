import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../login/login_screen.dart';
import '../esqueceu_senha/alterar_senha_screen.dart';
import '../dados_pessoais/dados_pessoais_screen.dart';
import '../pedidos/meus_pedidos_screen.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_page_header.dart';
import '../../cashback/cashback_screen.dart';
import '../../services/main_navigation_controller.dart';
import 'informacoes_aplicativo_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final authStorage = AuthStorage();
  final apiService = ApiService();
  late final Future<Map<String, String>> _dadosCabecalho;

  @override
  void initState() {
    super.initState();
    _dadosCabecalho = _carregarDadosCabecalho();
  }

  Future<Map<String, String>> _carregarDadosCabecalho() async {
    final nomeSalvo = (await authStorage.obterNmcliente())?.trim() ?? '';

    try {
      final perfil = await apiService.buscarMeuPerfil();
      final nome = (perfil['nmcliente'] ?? '').toString().trim();
      final email = (perfil['emailcliente'] ?? '').toString().trim();
      return {'nome': nome.isEmpty ? nomeSalvo : nome, 'email': email};
    } catch (_) {
      return {
        'nome': nomeSalvo.isEmpty ? 'Cliente Clubbar' : nomeSalvo,
        'email': '',
      };
    }
  }

  Future<void> fazerLogout() async {
    await authStorage.limparToken();

    if (!mounted) return;

    AppSnackBar.erro(context, 'Logout realizado com sucesso.');

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(mostrarVoltar: false),
      ),
      (route) => false,
    );
  }

  void abrirCashback() {
    SnackBar(
      content: Text(
        'Funcionalidade de cashback ainda não implementada.',
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.red,
    );
  }

  void faleConosco() {
    SnackBar(
      content: Text(
        'Funcionalidade de fale conosco ainda não implementada.',
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: const Color.fromARGB(255, 134, 96, 194),
    );
  }

  void abrirPedidos() {
    MainNavigationController.abrirTela(const MeusPedidosScreen());
  }

  Widget _itemAcao({
    required IconData icon,
    required String titulo,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (iconColor ?? Colors.amber).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor ?? Colors.amber.shade800),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      extendBodyBehindAppBar: false,
      appBar: const ClubbarAppBar(
        titulo: 'Perfil',
        mostrarVoltar: true,
        mostrarSessao: false,
      ),
      body: Column(
        children: [
          FutureBuilder<Map<String, String>>(
            future: _dadosCabecalho,
            builder: (context, snapshot) {
              final dados = snapshot.data;
              return ClubbarPageHeader(
                titulo: dados?['nome'] ?? 'Cliente Clubbar',
                subtitulo: dados?['email'] ?? '',
                mostrarAvatar: false,
                corTitulo: Colors.blue,
              );
            },
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
              children: [
                _itemAcao(
                  icon: Icons.badge_rounded,
                  titulo: 'Dados pessoais',
                  onTap: () {
                    MainNavigationController.abrirTela(
                      const DadosPessoaisScreen(),
                    );
                  },
                  iconColor: Colors.blue,
                ),

                const SizedBox(height: 10),

                _itemAcao(
                  icon: Icons.password_rounded,
                  titulo: 'Alterar senha',
                  onTap: () {
                    MainNavigationController.abrirTela(
                      AlterarSenhaScreen(
                        onVoltar: MainNavigationController.fecharTelaInterna,
                      ),
                    );
                  },
                  iconColor: Colors.green,
                ),

                const SizedBox(height: 10),

                _itemAcao(
                  icon: Icons.receipt_long_rounded,
                  titulo: 'Minhas compras',
                  onTap: abrirPedidos,
                  iconColor: Colors.orange,
                ),

                const SizedBox(height: 10),
                _itemAcao(
                  icon: Icons.savings_rounded,
                  titulo: 'Cashback',
                  onTap: () {
                    MainNavigationController.abrirTela(const CashbackScreen());
                  },
                  iconColor: Colors.green,
                ),

                const SizedBox(height: 10),

                _itemAcao(
                  icon: Icons.info_outline_rounded,
                  titulo: 'Sobre o aplicativo',
                  onTap: () {
                    MainNavigationController.abrirTela(
                      const InformacoesAplicativoScreen(),
                    );
                  },
                  iconColor: Colors.blueGrey,
                ),

                const SizedBox(height: 10),

                _itemAcao(
                  icon: Icons.logout_rounded,
                  titulo: 'Sair',
                  onTap: fazerLogout,
                  iconColor: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget itemMenu({
    required IconData icon,
    required Color corIcone,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: corIcone.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: corIcone),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
