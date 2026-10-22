import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/cart_badge_notifier.dart';
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
  String _nomeCabecalho = 'Cliente Clubbar';
  String _emailCabecalho = '';
  bool _cabecalhoPronto = false;

  @override
  void initState() {
    super.initState();
    _carregarDadosCabecalho();
  }

  Future<void> _carregarDadosCabecalho() async {
    final nomeSalvo = (await authStorage.obterNmcliente())?.trim() ?? '';

    try {
      final perfil = await apiService.buscarMeuPerfil();
      final nome = (perfil['nmcliente'] ?? '').toString().trim();
      final email = (perfil['emailcliente'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() {
        _nomeCabecalho = nome.isEmpty
            ? (nomeSalvo.isEmpty ? 'Cliente Clubbar' : nomeSalvo)
            : nome;
        _emailCabecalho = email;
        _cabecalhoPronto = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nomeCabecalho = nomeSalvo.isEmpty ? 'Cliente Clubbar' : nomeSalvo;
        _cabecalhoPronto = true;
      });
    }
  }

  Future<void> fazerLogout() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Você precisará informar seus dados para entrar novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contextoDialogo, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(contextoDialogo, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    await authStorage.limparToken();

    if (!mounted) return;

    AppSnackBar.sucesso(context, 'Logout realizado com sucesso.');

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(mostrarVoltar: false),
      ),
      (route) => false,
    );
  }

  Future<void> excluirMinhaConta() async {
    final senhaController = TextEditingController();
    final senha = await showDialog<String>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: const Text('Excluir conta permanentemente?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seu acesso será encerrado e seus dados pessoais serão excluídos. '
                'Registros de pagamento poderão ser mantidos somente quando exigidos por lei.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: senhaController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Confirme sua senha',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contextoDialogo),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final senha = senhaController.text;
              if (senha.isNotEmpty) Navigator.pop(contextoDialogo, senha);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir conta'),
          ),
        ],
      ),
    );
    senhaController.dispose();

    if (senha == null || senha.isEmpty || !mounted) return;

    try {
      await apiService.excluirMinhaConta(senhaAtual: senha);
      await authStorage.limparToken();
      CartBadgeNotifier.limpar();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(mostrarVoltar: false),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    }
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? Colors.amber.shade800, size: 25),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.normal,
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
      appBar: ClubbarAppBar(
        titulo: 'Perfil',
        iconeTitulo: Icons.person_rounded,
        corIconeTitulo: Colors.amber,
        mostrarVoltar: true,
        mostrarSessao: false,
        onVoltar: MainNavigationController.irParaHome,
      ),
      body: Column(
        children: [
          _cabecalhoPronto
              ? ClubbarPageHeader(
                  titulo: _nomeCabecalho,
                  subtitulo: _emailCabecalho,
                  mostrarAvatar: false,
                  corTitulo: Colors.blue,
                )
              : const SizedBox(height: 70),

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
                  icon: Icons.delete_forever_rounded,
                  titulo: 'Excluir minha conta',
                  onTap: excluirMinhaConta,
                  iconColor: Colors.red,
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
