import 'package:flutter/material.dart';

import '../../models/categoria.dart';
import '../../models/loja.dart';
import '../../models/produto.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../carrinho/carrinho_screen.dart';

class ProdutosLojaScreen extends StatefulWidget {
  final Loja loja;

  const ProdutosLojaScreen({super.key, required this.loja});

  @override
  State<ProdutosLojaScreen> createState() => _ProdutosLojaScreenState();
}

class _ProdutosLojaScreenState extends State<ProdutosLojaScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();

  bool carregando = true;
  String? erro;

  List<Categoria> categorias = [];
  List<Produto> produtos = [];
  int? categoriaSelecionadaId;
  int? clienteId;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      clienteId = await authStorage.obterClienteId();

      final resultados = await Future.wait([
        apiService.buscarCategoriasPorLoja(widget.loja.id),
        apiService.buscarProdutosPorLoja(widget.loja.id),
      ]);

      categorias = resultados[0] as List<Categoria>;
      produtos = resultados[1] as List<Produto>;

      if (categorias.isNotEmpty) {
        categoriaSelecionadaId ??= categorias.first.id;
      }

      setState(() {
        carregando = false;
      });
    } catch (e) {
      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '');
        carregando = false;
      });
    }
  }

  Future<void> adicionarProdutoAoCarrinho(Produto produto) async {
    if (clienteId == null || clienteId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faça login para adicionar itens ao carrinho'),
        ),
      );
      return;
    }

    try {
      await apiService.adicionarAoCarrinho(
        clienteId: clienteId!,
        organizacaoId: widget.loja.organizacaoId,
        lojaId: widget.loja.id,
        produtoId: produto.id,
        quantidade: 1,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${produto.nome}" adicionado ao carrinho')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  List<Produto> get produtosFiltrados {
    if (categoriaSelecionadaId == null) return produtos;

    return produtos
        .where((p) => p.categoriaId == categoriaSelecionadaId)
        .toList();
  }

  Widget _imagemProduto(String url) {
    if (url.isEmpty) {
      return Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.fastfood_outlined),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        url,
        width: 86,
        height: 86,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 86,
          height: 86,
          color: Colors.grey.shade200,
          child: const Icon(Icons.image_not_supported),
        ),
      ),
    );
  }

  Widget _chipCategoria(Categoria categoria) {
    final selecionada = categoriaSelecionadaId == categoria.id;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(categoria.nome),
        selected: selecionada,
        onSelected: (_) {
          setState(() {
            categoriaSelecionadaId = categoria.id;
          });
        },
        selectedColor: Colors.amber,
        labelStyle: TextStyle(
          color: selecionada ? Colors.black : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _cardProduto(Produto produto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => adicionarProdutoAoCarrinho(produto),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _imagemProduto(produto.imagemUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        produto.nome,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        produto.descricao.isEmpty
                            ? 'Sem descrição'
                            : produto.descricao,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'R\$ ${produto.preco.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => adicionarProdutoAoCarrinho(produto),
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      tooltip: 'Adicionar ao carrinho',
                    ),
                  ],
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
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.restaurant_menu_rounded,
            size: 58,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          const Text(
            'Nenhum produto encontrado',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Não há produtos disponíveis nesta categoria no momento.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
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
              erro ?? 'Erro ao carregar produtos',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: carregarDados,
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
      appBar: AppBar(
        title: Text('Produtos - ${widget.loja.nome}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Carrinho',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CarrinhoScreen(loja: widget.loja),
                ),
              );
            },
          ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro != null
          ? _erroWidget()
          : RefreshIndicator(
              onRefresh: carregarDados,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Categorias',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  if (categorias.isEmpty)
                    const Text('Nenhuma categoria disponível.')
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categorias.map(_chipCategoria).toList(),
                      ),
                    ),
                  const SizedBox(height: 22),
                  const Text(
                    'Produtos',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  if (produtosFiltrados.isEmpty)
                    _estadoVazio()
                  else
                    ...produtosFiltrados.map(_cardProduto),
                ],
              ),
            ),
    );
  }
}
