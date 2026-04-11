import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../carteira/carteira_screen.dart';
import '../carrinho/carrinho_lojas_screen.dart';
import '../home/home_screen.dart';
import '../login/login_screen.dart';
import '../perfil/perfil_screen.dart';
import '../../models/loja.dart';
import '../carrinho/carrinho_screen.dart';

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

  @override
  void initState() {
    super.initState();
    carregarBadgeCarrinho();
  }

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

  Future<void> _abrirCarrinho() async {
    final logado = await _estaLogado();

    if (!logado) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para acessar seu carrinho')),
      );

      final resultado = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );

      if (resultado == true) {
        await carregarBadgeCarrinho();
      }

      return;
    }

    if (totalItensCarrinho == 0) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seu carrinho está vazio')));

      return;
    }

    try {
      final clienteId = await authStorage.obterClienteId();

      if (clienteId == null || clienteId == 0) {
        throw Exception('Cliente não identificado');
      }

      final lojasCarrinho = await apiService.buscarLojasComCarrinho(
        clienteId: clienteId,
      );

      if (!mounted) return;

      if (lojasCarrinho.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seu carrinho está vazio')),
        );
        await carregarBadgeCarrinho();
        return;
      }

      if (lojasCarrinho.length == 1) {
        final lojaData = lojasCarrinho.first;

        String buildImageUrl(String path) {
          if (path.isEmpty) return '';
          if (path.startsWith('http')) return path;
          return 'https://bitbeer-production.up.railway.app$path';
        }

        final loja = Loja(
          id: int.tryParse('${lojaData['loja_id']}') ?? 0,
          organizacaoId: int.tryParse('${lojaData['organizacao_id']}') ?? 0,
          nome: (lojaData['nmloja'] ?? 'Loja').toString(),
          bairro: (lojaData['dsbairroloja'] ?? '').toString(),
          horario: '',
          imagemUrl: buildImageUrl((lojaData['urllogoloja'] ?? '').toString()),
          instagram: '',
        );

        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CarrinhoScreen(loja: loja)),
        );

        await carregarBadgeCarrinho();
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CarrinhoLojasScreen()),
      );

      await carregarBadgeCarrinho();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _selecionarAba(int index) async {
    // 0 = Home
    // 1 = Carrinho (abre por push)
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
        if (!mounted) return;

        final mensagem = index == 2
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
          await carregarBadgeCarrinho();

          setState(() {
            currentIndex = index == 2 ? 1 : 2;
          });
        }

        return;
      }
    }

    if (!mounted) return;

    setState(() {
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
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
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
