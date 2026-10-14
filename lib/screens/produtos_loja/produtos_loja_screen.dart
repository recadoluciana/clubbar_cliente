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
import '../../widgets/clubbar_contact_links.dart';
import '../carrinho/carrinho_screen.dart';
import '../pagamento/politica_compra_screen.dart';

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
  int carrinhoDaLojaId = 0;
  Map<int, int> quantidadesPorProduto = {};
  final Set<int> produtosEmAlteracao = {};

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
          carrinhoDaLojaId = 0;
          quantidadesPorProduto = {};
        });

        return;
      }

      final resultados = await Future.wait([
        apiService.buscarQuantidadeCarrinho(clienteId: id),
        apiService.buscarCarrinho(
          clienteId: id,
          organizacaoId: widget.loja.organizacaoId,
          lojaId: widget.loja.id,
        ),
      ]);
      final total = resultados[0] as int;
      final carrinhoLoja = resultados[1] as Map<String, dynamic>;
      final itens = carrinhoLoja['itens'];
      final quantidades = <int, int>{};
      var totalLoja = 0;

      if (itens is List) {
        for (final item in itens) {
          if (item is! Map) continue;
          final produtoId = int.tryParse('${item['produto_id']}');
          final quantidade = int.tryParse('${item['qt']}') ?? 1;
          final observacao = '${item['observacao'] ?? ''}'.trim();

          // O controle no cardápio gerencia somente as unidades sem
          // observação. Itens personalizados continuam sendo ajustados no
          // carrinho, onde a observação fica visível.
          if (produtoId != null && observacao.isEmpty) {
            quantidades[produtoId] = (quantidades[produtoId] ?? 0) + quantidade;
          }
          totalLoja += quantidade;
        }
      }

      CartBadgeNotifier.atualizar(total);

      if (!mounted) return;
      setState(() {
        quantidadeCarrinho = totalLoja;
        carrinhoDaLojaId =
            int.tryParse('${carrinhoLoja['carrinho_id'] ?? 0}') ?? 0;
        quantidadesPorProduto = quantidades;
      });
    } catch (_) {
      CartBadgeNotifier.limpar();

      if (!mounted) return;
      setState(() {
        quantidadeCarrinho = 0;
        carrinhoDaLojaId = 0;
        quantidadesPorProduto = {};
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

    if (produtosEmAlteracao.contains(produto.produtoId)) return;

    final quantidadeAnterior = quantidadesPorProduto[produto.produtoId] ?? 0;
    setState(() => produtosEmAlteracao.add(produto.produtoId));

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

      if (!mounted) return;
      await carregarQuantidadeCarrinho();

      if (!mounted || quantidadeAnterior > 0) return;
      AppSnackBar.info(
        context,
        observacao.trim().isEmpty
            ? '"${produto.nmproduto}" adicionado ao carrinho'
            : '"${produto.nmproduto}" adicionado ao carrinho com observação',
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => produtosEmAlteracao.remove(produto.produtoId));
      }
    }
  }

  Future<void> removerProdutoDoCarrinho(Produto produto) async {
    if (produtosEmAlteracao.contains(produto.produtoId)) return;
    if (carrinhoDaLojaId == 0) {
      await carregarQuantidadeCarrinho();
      return;
    }

    setState(() => produtosEmAlteracao.add(produto.produtoId));
    try {
      await apiService.removerItemCarrinho(
        carrinhoId: carrinhoDaLojaId,
        produtoId: produto.produtoId,
        observacao: '',
      );
      if (!mounted) return;
      await carregarQuantidadeCarrinho();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => produtosEmAlteracao.remove(produto.produtoId));
      }
    }
  }

  Future<void> _abrirCarrinhoDaLoja() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CarrinhoScreen(loja: widget.loja)),
    );

    if (mounted) await carregarQuantidadeCarrinho();
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
        hintText: 'produto, categoria, descrição',
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
        titulo: 'Cardápio - ${widget.loja.nome}',
        mostrarVoltar: true,
        mostrarSessao: false,
        mostrarCarrinho: true,
        quantidadeCarrinho: quantidadeCarrinho,
        onCarrinhoTap: _abrirCarrinhoDaLoja,
        onVoltar: () {
          // O cardápio é aberto pela navegação interna do Client. Fechá-la
          // primeiro evita que o navegador intercepte o retorno e mantenha a
          // tela atual visível.
          if (MainNavigationController.telaInterna.value != null) {
            MainNavigationController.fecharTelaInterna();
            return;
          }

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
          ? Column(children: [Expanded(child: _erroWidget())])
          : Column(
              children: [
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
                        else ...[
                          ...produtosFiltrados.map(_cardProdutoLista),
                          const SizedBox(height: 4),
                          Center(
                            child: Column(
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const PoliticaCompraScreen(
                                              tipo: 'PRODUTO',
                                            ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.policy_outlined,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Política de compra de produto',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                ClubbarContactLinks(
                                  emailEstabelecimento:
                                      widget.loja.emailContato,
                                  whatsappEstabelecimento: widget.loja.whatsapp,
                                ),
                              ],
                            ),
                          ),
                        ],
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
            height: 136,
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
                          child: _controleQuantidadeProduto(produto),
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

  Widget _controleQuantidadeProduto(Produto produto) {
    final quantidade = quantidadesPorProduto[produto.produtoId] ?? 0;
    final alterando = produtosEmAlteracao.contains(produto.produtoId);

    if (quantidade == 0) {
      return SizedBox(
        height: 30,
        child: ElevatedButton.icon(
          onPressed: alterando
              ? null
              : () => adicionarProdutoAoCarrinho(produto),
          icon: alterando
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_shopping_cart_rounded, size: 15),
          label: const Text(
            'Adicionar',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _botaoQuantidade(
            icone: Icons.remove_rounded,
            dica: 'Remover uma unidade',
            habilitado: !alterando,
            aoPressionar: () => removerProdutoDoCarrinho(produto),
          ),
          SizedBox(
            width: 28,
            child: Center(
              child: alterando
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '$quantidade',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
          _botaoQuantidade(
            icone: Icons.add_rounded,
            dica: 'Adicionar uma unidade',
            habilitado: !alterando,
            aoPressionar: () => adicionarProdutoAoCarrinho(produto),
          ),
        ],
      ),
    );
  }

  Widget _botaoQuantidade({
    required IconData icone,
    required String dica,
    required bool habilitado,
    required VoidCallback aoPressionar,
  }) => Tooltip(
    message: dica,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: habilitado ? aoPressionar : null,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icone,
            size: 18,
            color: habilitado ? Colors.black87 : Colors.grey,
          ),
        ),
      ),
    ),
  );
}
