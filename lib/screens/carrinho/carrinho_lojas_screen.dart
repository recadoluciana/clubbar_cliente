import 'package:flutter/material.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import 'carrinho_screen.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/clubbar_page_header.dart';

class CarrinhoLojasScreen extends StatefulWidget {
  const CarrinhoLojasScreen({super.key});

  @override
  State<CarrinhoLojasScreen> createState() => _CarrinhoLojasScreenState();
}

class _CarrinhoLojasScreenState extends State<CarrinhoLojasScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();

  static const String baseUrl = 'https://api.clubbar.com.br';

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
    if (url.isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.storefront_outlined, color: Colors.amber.shade800),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        url,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.storefront_outlined,
              color: Colors.amber.shade800,
            ),
          );
        },
      ),
    );
  }

  Widget _cardLoja(Map<String, dynamic> lojaData) {
    final loja = Loja(
      id: int.tryParse('${lojaData['loja_id']}') ?? 0,
      organizacaoId: int.tryParse('${lojaData['organizacao_id']}') ?? 0,
      nome: (lojaData['nmloja'] ?? 'Loja').toString(),
      endereco: (lojaData['endereco'] ?? '').toString(),
      cidade: (lojaData['cidade'] ?? '').toString(),
      bairro: (lojaData['bairro'] ?? '').toString(),
      horario: (lojaData['horario'] ?? '').toString(),
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
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CarrinhoScreen(loja: loja)),
            );

            if (!mounted) return;
            await carregarLojasCarrinho();
          },
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip(
                            qtItens == 1
                                ? '1 item no carrinho'
                                : '$qtItens itens no carrinho',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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

      appBar: const ClubbarAppBar(mostrarVoltar: true),

      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const ClubbarPageHeader(
                  titulo: 'Carrinho',
                  subtitulo: 'Itens pendentes de pagamento por estabelecimento',
                  icone: Icons.shopping_cart_rounded,
                ),

                Expanded(
                  child: RefreshIndicator(
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
                ),
              ],
            ),
    );
  }
}
