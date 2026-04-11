import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../carteira/carteira_screen.dart';
import '../carrinho/carrinho_lojas_screen.dart';
import '../home/home_screen.dart';
import '../login/login_screen.dart';
import '../perfil/perfil_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final authStorage = AuthStorage();
  final apiService = ApiService();

  int currentIndex = 0;
  int totalItensCarrinho = 0;
  int totalItensCarteira = 0;

  @override
  void initState() {
    super.initState();
    carregarBadgeCarrinho();
    carregarBadgeCarteira();
  }

  Widget _buildPage() {
    switch (currentIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const CarrinhoLojasScreen();
      case 2:
        return const CarteiraScreen();
      case 3:
        return const PerfilScreen();
      default:
        return const HomeScreen();
    }
  }

  Future<bool> _estaLogado() async {
    final token = await authStorage.obterToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> carregarBadgeCarrinho() async {
    try {
      final clienteId = await authStorage.obterClienteId();

      if (clienteId == null || clienteId == 0) {
        if (!mounted) return;
        setState(() {
          totalItensCarrinho = 0;
        });
        return;
      }

      final total = await apiService.buscarQuantidadeCarrinho(
        clienteId: clienteId,
      );

      if (!mounted) return;

      setState(() {
        totalItensCarrinho = total;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        totalItensCarrinho = 0;
      });
    }
  }

  Future<void> carregarBadgeCarteira() async {
    try {
      final clienteId = await authStorage.obterClienteId();

      if (clienteId == null || clienteId == 0) {
        if (!mounted) return;
        setState(() {
          totalItensCarteira = 0;
        });
        return;
      }

      final total = await apiService.buscarQuantidadeCarteira(
        clienteId: clienteId,
      );

      if (!mounted) return;

      setState(() {
        totalItensCarteira = total;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        totalItensCarteira = 0;
      });
    }
  }

  Widget _iconeCarrinhoComBadge({required bool selecionado}) {
    final icone = Icon(
      selecionado ? Icons.shopping_cart : Icons.shopping_cart_outlined,
    );

    if (totalItensCarrinho <= 0) {
      return icone;
    }

    return Badge(
      label: Text(
        totalItensCarrinho > 99 ? '99+' : '$totalItensCarrinho',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: icone,
    );
  }

  Widget _iconeCarteiraComBadge({required bool selecionado}) {
    final icone = Icon(
      selecionado
          ? Icons.account_balance_wallet
          : Icons.account_balance_wallet_outlined,
    );

    if (totalItensCarteira <= 0) {
      return icone;
    }

    return Badge(
      backgroundColor: Colors.green,
      label: Text(
        totalItensCarteira > 99 ? '99+' : '$totalItensCarteira',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: icone,
    );
  }

  Future<void> _selecionarAba(int index) async {
    final exigeLogin = index == 1 || index == 2 || index == 3;

    if (exigeLogin) {
      final logado = await _estaLogado();

      if (!logado) {
        if (!mounted) return;

        String mensagem = 'Faça login para continuar';

        if (index == 1) {
          mensagem = 'Faça login para acessar seu carrinho';
        } else if (index == 2) {
          mensagem = 'Faça login para acessar sua carteira';
        } else if (index == 3) {
          mensagem = 'Faça login para acessar seu perfil';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagem)));

        final resultado = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );

        if (!mounted) return;

        if (resultado == true) {
          await carregarBadgeCarrinho();
          await carregarBadgeCarteira();

          setState(() {
            currentIndex = index;
          });
        }

        return;
      }

      if (index == 1 && totalItensCarrinho == 0) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seu carrinho está vazio')),
        );
        return;
      }
    }

    if (!mounted) return;

    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: _selecionarAba,
        height: 72,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: _iconeCarrinhoComBadge(selecionado: false),
            selectedIcon: _iconeCarrinhoComBadge(selecionado: true),
            label: 'Carrinho',
          ),
          NavigationDestination(
            icon: _iconeCarteiraComBadge(selecionado: false),
            selectedIcon: _iconeCarteiraComBadge(selecionado: true),
            label: 'Carteira',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
