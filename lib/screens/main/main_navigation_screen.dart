import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../carteira/carteira_screen.dart';
import '../carrinho/carrinho_lojas_screen.dart';
import '../home/home_screen.dart';
import '../login/login_screen.dart';
import '../perfil/perfil_screen.dart';
import '../../services/cart_badge_notifier.dart';
import '../../services/carteira_badge_notifier.dart';
import '../../services/main_navigation_controller.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final authStorage = AuthStorage();
  final apiService = ApiService();

  int currentIndex = 0;
  int totalItensCarteira = 0;

  String nomeCliente = '';
  bool logado = false;

  @override
  void initState() {
    super.initState();
    carregarUsuario();
    carregarBadgeCarrinho();
    carregarBadgeCarteira();

    CarteiraBadgeNotifier.refresh.addListener(() {
      carregarBadgeCarteira();
    });
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

  String _primeiroNome(String nomeCompleto) {
    final partes = nomeCompleto.trim().split(' ');
    return partes.isNotEmpty ? partes.first : '';
  }

  Future<bool> _estaLogado() async {
    final token = await authStorage.obterToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> carregarUsuario() async {
    final token = await authStorage.obterToken();
    final nome = await authStorage.obterNmcliente();

    if (!mounted) return;

    setState(() {
      logado = token != null && token.isNotEmpty;
      nomeCliente = nome ?? '';
    });
  }

  Future<void> carregarBadgeCarrinho() async {
    try {
      final clienteId = await authStorage.obterClienteId();

      if (clienteId == null || clienteId == 0) {
        CartBadgeNotifier.limpar();
        return;
      }

      final total = await apiService.buscarQuantidadeCarrinho(
        clienteId: clienteId,
      );

      CartBadgeNotifier.atualizar(total);
    } catch (_) {
      CartBadgeNotifier.limpar();
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
    return ValueListenableBuilder<int>(
      valueListenable: CartBadgeNotifier.totalItens,
      builder: (context, totalItensCarrinho, _) {
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
      },
    );
  }

  Widget _iconeCarteiraComBadge({required bool selecionado}) {
    return ValueListenableBuilder<int>(
      valueListenable: CarteiraBadgeNotifier.refresh,
      builder: (context, _, __) {
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
      },
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
          await carregarUsuario();
          await carregarBadgeCarrinho();
          await carregarBadgeCarteira();

          setState(() {
            currentIndex = index;
          });
        }

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
    return ValueListenableBuilder<int>(
      valueListenable: MainNavigationController.abaIndex,
      builder: (context, abaAtual, _) {
        currentIndex = abaAtual;

        return Scaffold(
          body: ValueListenableBuilder<Widget?>(
            valueListenable: MainNavigationController.telaInterna,
            builder: (context, telaInterna, _) {
              return telaInterna ?? _buildPage();
            },
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              MainNavigationController.fecharTelaInterna();
              MainNavigationController.abaIndex.value = index;
              _selecionarAba(index);
            },
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
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: logado && nomeCliente.trim().isNotEmpty
                    ? _primeiroNome(nomeCliente)
                    : 'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }
}
