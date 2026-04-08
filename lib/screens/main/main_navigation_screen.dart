import 'package:flutter/material.dart';

import '../../services/auth_storage.dart';
import '../carteira/carteira_screen.dart';
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

  Future<void> _selecionarAba(int index) async {
    final exigeLogin = index == 1 || index == 2;

    if (exigeLogin) {
      final logado = await _estaLogado();

      if (!logado) {
        if (!mounted) return;

        final mensagem = index == 1
            ? 'Faça login para acessar sua carteira'
            : 'Faça login para acessar seu perfil';

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagem)));

        final resultado = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );

        if (!mounted) return;

        if (resultado == true) {
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
    return Scaffold(
      body: _buildPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: _selecionarAba,
        height: 72,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
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
