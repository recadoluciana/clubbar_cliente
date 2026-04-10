import 'package:flutter/material.dart';

import '../../services/auth_storage.dart';
import '../carteira/carteira_screen.dart';
import '../home/home_screen.dart';
import '../login/login_screen.dart';
import '../perfil/perfil_screen.dart';
import '../carrinho/carrinho_screen.dart';
import '../../models/loja.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final authStorage = AuthStorage();

  int currentIndex = 0;

  Widget _buildPage() {
    switch (currentIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const CarteiraScreen();
      case 2:
        return const PerfilScreen();
      default:
        return const HomeScreen();
    }
  }

  Future<bool> _estaLogado() async {
    final token = await authStorage.obterToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> _abrirLoginComMensagem(String mensagem) async {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _abrirCarrinho() async {
    final logado = await _estaLogado();

    if (!logado) {
      await _abrirLoginComMensagem('Faça login para acessar seu carrinho');
      return;
    }

    // EXEMPLO TEMPORÁRIO:
    // aqui você precisa passar uma loja real.
    // troque pelos dados corretos da sua loja selecionada.
    final lojaTemp = Loja(
      id: 1,
      organizacaoId: 1,
      nome: 'Loja',
      bairro: '',
      horario: '',
      imagemUrl: '',
      instagram: '',
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CarrinhoScreen(loja: lojaTemp)),
    );
  }

  Future<void> _selecionarAba(int index) async {
    // 0 = Home
    // 1 = Carrinho
    // 2 = Carteira
    // 3 = Perfil

    if (index == 1) {
      await _abrirCarrinho();
      return;
    }

    final exigeLogin = index == 2 || index == 3;

    if (exigeLogin) {
      final logado = await _estaLogado();

      if (!logado) {
        final mensagem = index == 2
            ? 'Faça login para acessar sua carteira'
            : 'Faça login para acessar seu perfil';

        if (!mounted) return;

        final resultado = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );

        if (!mounted) return;

        if (resultado == true) {
          setState(() {
            currentIndex = index;
          });
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(mensagem)));
        }

        return;
      }
    }

    if (!mounted) return;

    setState(() {
      // como carrinho não ocupa o body, os índices visuais ficam:
      // 0 = Home
      // 2 = Carteira
      // 3 = Perfil
      if (index == 2) {
        currentIndex = 1;
      } else if (index == 3) {
        currentIndex = 2;
      } else {
        currentIndex = 0;
      }
    });
  }

  int _selectedNavIndex() {
    if (currentIndex == 1) return 2;
    if (currentIndex == 2) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex(),
        onDestinationSelected: _selecionarAba,
        height: 72,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Carrinho',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Carteira',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
