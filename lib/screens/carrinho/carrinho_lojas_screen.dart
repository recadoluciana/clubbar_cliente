import 'package:flutter/material.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import 'carrinho_screen.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../services/main_navigation_controller.dart';
import 'package:clubbar_cliente/config/app_config.dart';

class CarrinhoLojasScreen extends StatefulWidget {
  const CarrinhoLojasScreen({super.key});

  @override
  State<CarrinhoLojasScreen> createState() => _CarrinhoLojasScreenState();
}

class _CarrinhoLojasScreenState extends State<CarrinhoLojasScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();

  static final String baseUrl = AppConfig.apiBaseUrl;

  bool carregando = true;
  String? erro;
  int? clienteId;

  List<Map<String, dynamic>> lojasCarrinho = [];

  @override
  void initState() {
    super.initState();
    carregarLojasCarrinho();
  }

  Future<void> carregarLojasCarrinho() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final id = await authStorage.obterClienteId();

      if (id == null || id == 0) {
        throw Exception('Cliente não identificado. Faça login novamente.');
      }

      clienteId = id;

      final data = await apiService.buscarLojasComCarrinho(clienteId: id);

      if (!mounted) return;
      setState(() {
        lojasCarrinho = data;
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        erro = apiService.mensagemErroAmigavel(e);
        lojasCarrinho = [];
        carregando = false;
      });
    }
  }

  String _buildImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }

  Widget _logoLoja(String url) {
    Widget placeholder() {
      return Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.amber.shade200, width: 2),
        ),
        child: Icon(
          Icons.storefront_rounded,
          color: Colors.amber.shade800,
          size: 30,
        ),
      );
    }

    if (url.trim().isEmpty) return placeholder();

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          url,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder(),
        ),
      ),
    );
  }

  Future<void> _abrirCarrinhoDaLoja(Loja loja) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CarrinhoScreen(loja: loja)),
    );

    if (!mounted) return;
    await carregarLojasCarrinho();
  }

  Widget _cardLoja(Map<String, dynamic> lojaData) {
    final loja = Loja(
      id: int.tryParse('${lojaData['loja_id']}') ?? 0,
      organizacaoId: int.tryParse('${lojaData['organizacao_id']}') ?? 0,
      nome: (lojaData['nmloja'] ?? 'Loja').toString(),
      endereco: (lojaData['endereco'] ?? '').toString(),
      cidade: (lojaData['cidade'] ?? '').toString(),
      bairro: (lojaData['bairro'] ?? '').toString(),
      imagemUrl: _buildImageUrl((lojaData['urllogoloja'] ?? '').toString()),
      instagram: (lojaData['dsinstaloja'] ?? '').toString(),
      dsestiloloja: (lojaData['dsestiloloja'] ?? '').toString(),
      nrtelloja: (lojaData['nrtelloja'] ?? '').toString(),
      sgEstado: (lojaData['sgestado'] ?? '').toString(),

      // 👇 NOVO
      vrtaxaprod: double.tryParse('${lojaData['vrtaxaprod']}') ?? 3,
      vrtaxaing: double.tryParse('${lojaData['vrtaxaing']}') ?? 10,
    );

    final qtItens = int.tryParse('${lojaData['total_itens'] ?? 0}') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _abrirCarrinhoDaLoja(loja),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                _logoLoja(loja.imagemUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loja.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        qtItens == 1
                            ? '1 item no carrinho'
                            : '$qtItens itens no carrinho',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Abrir carrinho',
                  onPressed: () => _abrirCarrinhoDaLoja(loja),
                  icon: const Icon(Icons.chevron_right_rounded, size: 32),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _estadoVazio() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          const Text(
            'Você não tem carrinhos ativos',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _erroWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 56),
            const SizedBox(height: 14),
            Text(
              erro ?? 'Erro ao carregar lojas do carrinho',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: carregarLojasCarrinho,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: ClubbarAppBar(
        titulo: 'Meu Carrinho',
        iconeTitulo: Icons.shopping_cart_rounded,
        mostrarVoltar: true,
        mostrarLogo: false,
        mostrarSessao: false,
        onVoltar: MainNavigationController.irParaHome,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: carregando ? null : carregarLojasCarrinho,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),

      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: carregarLojasCarrinho,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  if (erro != null)
                    _erroWidget()
                  else if (lojasCarrinho.isEmpty)
                    _estadoVazio()
                  else
                    ...lojasCarrinho.map(_cardLoja),
                ],
              ),
            ),
    );
  }
}
