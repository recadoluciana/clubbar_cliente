import 'package:flutter/material.dart';

import '../../models/categoria.dart';
import '../../models/loja.dart';
import '../../models/produto.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../carrinho/carrinho_screen.dart';
import '../../services/cart_badge_notifier.dart';
import '../../utils/value_formatters.dart';

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

  int quantidadeCarrinho = 0;

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

      for (final p in produtos) {
        debugPrint(
          'PRODUTO: ${p.nmproduto} | preco=${ValueFormatters.moeda(p.vrprecoprod)} | final=${ValueFormatters.moeda(vrprecofinal)} | tipo=${p.tipodesconto} | desconto=${p.vrdesconto} | ativo=${p.descontoativo}',
        );
      }

      if (categorias.isNotEmpty) {
        categoriaSelecionadaId ??= categorias.first.id;
      }

      setState(() {
        carregando = false;
      });

      await carregarQuantidadeCarrinho();
    } catch (e) {
      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '');
        carregando = false;
      });
    }
  }

  Future<void> carregarQuantidadeCarrinho() async {
    try {
      final id = clienteId ?? await authStorage.obterClienteId();

      if (id == null || id == 0) {
        CartBadgeNotifier.limpar();

        if (!mounted) return;
        setState(() {
          quantidadeCarrinho = 0;
        });

        return;
      }

      final total = await apiService.buscarQuantidadeCarrinho(clienteId: id);

      CartBadgeNotifier.atualizar(total);

      if (!mounted) return;
      setState(() {
        quantidadeCarrinho = total;
      });
    } catch (_) {
      CartBadgeNotifier.limpar();

      if (!mounted) return;
      setState(() {
        quantidadeCarrinho = 0;
      });
    }
  }

  Future<void> adicionarProdutoAoCarrinho(
    Produto produto, {
    String observacao = '',
  }) async {
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
        produtoId: produto.produtoId,
        quantidade: 1,
        observacao: observacao,
      );

      final total = await apiService.buscarQuantidadeCarrinho(
        clienteId: clienteId!,
      );
      CartBadgeNotifier.atualizar(total);

      if (!mounted) return;

      setState(() {
        quantidadeCarrinho += 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            observacao.trim().isEmpty
                ? '"${produto.nmproduto}" adicionado ao carrinho'
                : '"${produto.nmproduto}" adicionado ao carrinho com observação',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> abrirDialogObservacao(Produto produto) async {
    final controller = TextEditingController();

    final resultado = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Observação - ${produto.nmproduto}'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ex.: sem cebola, bem passado, tirar gelo...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Sem observação'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );

    if (resultado == null) return;

    await adicionarProdutoAoCarrinho(produto, observacao: resultado);
  }

  List<Produto> get produtosFiltrados {
    if (categoriaSelecionadaId == null) return produtos;

    return produtos
        .where((p) => p.categoriaId == categoriaSelecionadaId)
        .toList();
  }

  Widget _imagemProduto(String? url) {
    if (url == null || url.isEmpty) {
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

  Widget _iconeCarrinhoComBadge() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CarrinhoScreen(loja: widget.loja)),
        );

        if (!mounted) return;
        await carregarQuantidadeCarrinho();
      },
      child: Padding(
        padding: EdgeInsets.zero,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 6,
                    color: Colors.black12,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.shopping_cart_outlined, size: 22),
            ),
            if (quantidadeCarrinho > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    quantidadeCarrinho > 99 ? '99+' : '$quantidadeCarrinho',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cardProduto(Produto produto) {
    final bool temDesconto = produto.descontoativo;

    final String seloDesconto =
        produto.tipodesconto.toUpperCase() == 'PERCENTUAL'
        ? '${produto.vrdesconto.toStringAsFixed(0)}% OFF'
        : 'R\$ ${produto.vrdesconto.toStringAsFixed(2)} OFF';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => abrirDialogObservacao(produto),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _imagemProduto(produto.urlfotoproduto),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (temDesconto)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            seloDesconto,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Text(
                        produto.nmproduto,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        produto.dsproduto.isEmpty
                            ? 'Sem descrição'
                            : produto.dsproduto,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (temDesconto) ...[
                        Text(
                          'R\$ ${ValueFormatters.moeda(produto.vrprecoprod)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'R\$ ${ValueFormatters.moeda(produto.vrprecofinal)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.green,
                          ),
                        ),
                      ] else
                        Text(
                          'R\$ ${ValueFormatters.moeda(produto.vrprecoprod)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () => abrirDialogObservacao(produto),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  tooltip: 'Adicionar ao carrinho',
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
      appBar: AppBar(title: Text('Produtos - ${widget.loja.nome}')),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro != null
          ? _erroWidget()
          : RefreshIndicator(
              onRefresh: carregarDados,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      const Text(
                        'Categorias',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      _iconeCarrinhoComBadge(),
                    ],
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
