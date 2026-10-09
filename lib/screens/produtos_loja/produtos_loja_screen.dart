import 'package:flutter/material.dart';

import '../../models/categoria.dart';
import '../../models/loja.dart';
import '../../models/produto.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/cart_badge_notifier.dart';
import '../../utils/value_formatters.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/login_redirect.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../services/main_navigation_controller.dart';
import 'produto_compartilhado_screen.dart';
import '../../utils/categoria_icon_utils.dart';
import '../../widgets/clubbar_page_header.dart';

class ProdutosLojaScreen extends StatefulWidget {
  final Loja loja;
  final VoidCallback? onVoltar;

  const ProdutosLojaScreen({super.key, required this.loja, this.onVoltar});

  @override
  State<ProdutosLojaScreen> createState() => _ProdutosLojaScreenState();
}

class _ProdutosLojaScreenState extends State<ProdutosLojaScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();

  bool carregando = true;
  bool semCardapioPublicado = false;
  String? erro;

  List<Categoria> categorias = [];
  List<Produto> produtos = [];
  int? categoriaSelecionadaId;
  int? clienteId;

  int quantidadeCarrinho = 0;

  final TextEditingController _buscaController = TextEditingController();
  String termoBusca = '';

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> carregarDados() async {
    setState(() {
      carregando = true;
      erro = null;
      semCardapioPublicado = false;
    });

    try {
      clienteId = await authStorage.obterClienteId();

      final resultados = await Future.wait([
        apiService.buscarCategoriasPorLoja(widget.loja.id),
        apiService.buscarProdutosPorLoja(widget.loja.id),
      ]);

      categorias = resultados[0] as List<Categoria>;
      produtos = (resultados[1] as List<Produto>)
          .where((produto) => produto.sitproduto.toUpperCase() == 'ATIVO')
          .toList();
      final categoriasComProdutos = produtos
          .map((produto) => produto.categoriaId)
          .toSet();
      categorias = categorias
          .where((categoria) => categoriasComProdutos.contains(categoria.id))
          .toList();

      categoriaSelecionadaId =
          categorias.any((categoria) => categoria.id == categoriaSelecionadaId)
          ? categoriaSelecionadaId
          : categorias.isNotEmpty
          ? categorias.first.id
          : null;

      setState(() {
        carregando = false;
      });

      await carregarQuantidadeCarrinho();
    } catch (e) {
      final mensagem = apiService.mensagemErroAmigavel(e);
      final semCardapio = mensagem.toLowerCase().contains(
        'nenhum cardápio publicado',
      );
      setState(() {
        semCardapioPublicado = semCardapio;
        erro = semCardapio
            ? 'Este estabelecimento ainda não possui cardápio publicado.'
            : mensagem.replaceFirst('Exception: ', '');
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
      await direcionarParaLogin(
        context,
        mensagem: 'Faça login para adicionar itens ao carrinho.',
      );
      return;
    }

    try {
      await apiService.adicionarAoCarrinho(
        clienteId: clienteId!,
        organizacaoId: widget.loja.organizacaoId,
        lojaId: widget.loja.id,
        produtoId: produto.produtoId,
        cardapioItemId: produto.cardapioItemId,
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

      AppSnackBar.info(
        context,
        observacao.trim().isEmpty
            ? '"${produto.nmproduto}" adicionado ao carrinho'
            : '"${produto.nmproduto}" adicionado ao carrinho com observação',
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  List<Produto> get produtosFiltrados {
    final pesquisa = termoBusca.trim().toLowerCase();

    // Se está pesquisando, ignora categoria e busca em todos os produtos
    if (pesquisa.isNotEmpty) {
      return produtos.where((produto) {
        final categoria = categorias
            .firstWhere(
              (c) => c.id == produto.categoriaId,
              orElse: () => Categoria(id: 0, nome: ''),
            )
            .nome
            .toLowerCase();

        return produto.nmproduto.toLowerCase().contains(pesquisa) ||
            produto.dsproduto.toLowerCase().contains(pesquisa) ||
            categoria.contains(pesquisa);
      }).toList();
    }

    // Se não está pesquisando, usa a categoria selecionada normalmente
    if (categoriaSelecionadaId == null) return produtos;

    return produtos
        .where((p) => p.categoriaId == categoriaSelecionadaId)
        .toList();
  }

  Widget _campoPesquisa() {
    return TextField(
      controller: _buscaController,
      onChanged: (texto) {
        setState(() {
          termoBusca = texto;
        });
      },
      decoration: InputDecoration(
        hintText: 'Produto, categoria ou descrição',
        hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        prefixIcon: const Icon(Icons.search_rounded, size: 22),
        suffixIcon: termoBusca.trim().isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar pesquisa',
                onPressed: () {
                  _buscaController.clear();

                  setState(() {
                    termoBusca = '';
                  });

                  FocusScope.of(context).unfocus();
                },
                icon: const Icon(Icons.close_rounded, size: 21),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.amber, width: 1.6),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _chipCategoria(Categoria categoria) {
    final selecionada = categoriaSelecionadaId == categoria.id;

    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          setState(() {
            categoriaSelecionadaId = categoria.id;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 62,
          height: 56,
          decoration: BoxDecoration(
            color: selecionada ? Colors.amber : Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selecionada ? Colors.amber : Colors.grey.shade300,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CategoriaIconUtils.porCategoria(
                    categoria.nome,
                    categoria.icone,
                  ),
                  color: CategoriaIconUtils.corPorNome(categoria.nome),
                  size: 18,
                ),
                const SizedBox(height: 3),
                Text(
                  categoria.nome,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: selecionada ? Colors.black : Colors.black87,
                  ),
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
            Icon(
              semCardapioPublicado
                  ? Icons.restaurant_menu_outlined
                  : Icons.cloud_off,
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              erro ?? 'Erro ao carregar produtos',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (!semCardapioPublicado) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: carregarDados,
                child: const Text('Tentar novamente'),
              ),
            ],
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
        titulo: widget.loja.nome,
        mostrarVoltar: true,
        mostrarSessao: false,
        onVoltar: () {
          if (widget.onVoltar != null) {
            widget.onVoltar!();
            return;
          }

          if (Navigator.canPop(context)) {
            Navigator.pop(context);
            return;
          }

          MainNavigationController.fecharTelaInterna();
        },
      ),

      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro != null
          ? _erroWidget()
          : Column(
              children: [
                ClubbarPageHeader(
                  titulo: 'Cardápio',
                  subtitulo: 'Selecione o produto que deseja comprar',
                  corTitulo: Colors.blue,
                  imagemAvatarUrl: widget.loja.imagemUrl,
                  tamanhoAvatar: 52,
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: _campoPesquisa(),
                ),

                if (termoBusca.trim().isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 12,
                    ),
                    child: SizedBox(
                      height: 64,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: categorias.map(_chipCategoria).toList(),
                      ),
                    ),
                  ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: carregarDados,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      children: [
                        if (produtosFiltrados.isEmpty)
                          _estadoVazio()
                        else
                          ...produtosFiltrados.map(_cardProdutoLista),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _cardProdutoLista(Produto produto) {
    final temDesconto = produto.descontoativo;

    final precoAtual = temDesconto ? produto.vrprecofinal : produto.vrprecoprod;

    final seloDesconto = produto.tipodesconto.toUpperCase() == 'PERCENTUAL'
        ? '${produto.vrdesconto.toStringAsFixed(0)}% OFF'
        : '${ValueFormatters.moeda(produto.vrdesconto)} OFF';

    final imagem = produto.urlfotoproduto ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            MainNavigationController.abrirTela(
              ProdutoCompartilhadoScreen(
                produtoId: produto.produtoId,
                lojaId: widget.loja.id,
              ),
            );
          },
          child: SizedBox(
            height: 128,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 110,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imagem.isEmpty
                          ? Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.fastfood_outlined,
                                size: 36,
                              ),
                            )
                          : ColoredBox(
                              color: Colors.grey.shade100,
                              child: Image.network(
                                imagem,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                      if (temDesconto)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              seloDesconto,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          produto.nmproduto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (temDesconto)
                          Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                              children: [
                                const TextSpan(text: 'de '),
                                TextSpan(
                                  text: ValueFormatters.moeda(
                                    produto.vrprecoprod,
                                  ),
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const TextSpan(text: ' por '),
                                TextSpan(
                                  text: ValueFormatters.moeda(precoAtual),
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            ValueFormatters.moeda(precoAtual),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),

                        const SizedBox(height: 3),
                        if (produto.dsproduto.trim().isNotEmpty)
                          Text(
                            produto.dsproduto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.2,
                              color: Colors.grey.shade700,
                            ),
                          )
                        else
                          const SizedBox(height: 12),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            height: 30,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  adicionarProdutoAoCarrinho(produto),
                              icon: const Icon(
                                Icons.add_shopping_cart_rounded,
                                size: 15,
                              ),
                              label: const Text(
                                'Adicionar',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
