import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/categoria.dart';
import '../../models/loja.dart';
import '../../models/produto.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/cart_badge_notifier.dart';
import '../../services/carteira_badge_notifier.dart';
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
  bool vendasHabilitadas = true;
  String? erro;

  List<Categoria> categorias = [];
  List<Produto> produtos = [];
  int? categoriaSelecionadaId;
  int? clienteId;

  int quantidadeCarrinho = 0;
  final Map<int, int> quantidadesSelecionadas = {};
  final Set<int> produtosEmAlteracao = {};
  final Map<int, Map<String, dynamic>> _roletasPorProduto = {};
  final Map<int, Map<String, dynamic>> _cortesiasPorProduto = {};
  final Map<int, Map<String, dynamic>> _pacotesPorProduto = {};

  final TextEditingController _buscaController = TextEditingController();
  String termoBusca = '';

  int _chaveItemCardapio(Produto produto) =>
      produto.cardapioItemId ?? produto.produtoId;

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
      quantidadesSelecionadas.clear();
    });

    try {
      clienteId = await authStorage.obterClienteId();

      final cardapio = await apiService.buscarCardapioPublicado(widget.loja.id);
      categorias = (cardapio['categorias'] as List? ?? const [])
          .map((item) => Categoria.fromJson(item))
          .toList();
      produtos = (cardapio['categorias'] as List? ?? const [])
          .expand((categoria) => (categoria['itens'] as List? ?? const []))
          .map((item) => Produto.fromJson(Map<String, dynamic>.from(item)))
          .where((produto) => produto.sitproduto.toUpperCase() == 'ATIVO')
          .toList();
      _roletasPorProduto.clear();
      _cortesiasPorProduto.clear();
      _pacotesPorProduto.clear();
      if (clienteId != null && clienteId! > 0) {
        final ofertas = await apiService.beneficiosProdutosAtivos(
          lojaId: widget.loja.id,
          clienteId: clienteId!,
        );
        for (final oferta in ofertas) {
          final produtoId = int.tryParse('${oferta['produto_id']}');
          if (produtoId == null) continue;
          if (oferta['tipo'] == 'ROLETA') {
            _roletasPorProduto[produtoId] = oferta;
          } else if (oferta['tipo'] == 'CORTESIA') {
            _cortesiasPorProduto[produtoId] = oferta;
          } else if (oferta['tipo'] == 'PACOTE') {
            _pacotesPorProduto[produtoId] = oferta;
          }
        }
      }
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
        vendasHabilitadas = cardapio['vendas_habilitadas'] != false;
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
      var totalLoja = 0;

      if (itens is List) {
        for (final item in itens) {
          if (item is! Map) continue;
          final quantidade = int.tryParse('${item['qt']}') ?? 1;
          totalLoja += quantidade;
        }
      }

      CartBadgeNotifier.atualizar(total);

      if (!mounted) return;
      setState(() {
        quantidadeCarrinho = totalLoja;
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
    required int quantidade,
    String observacao = '',
    int? beneficioResgateId,
    int? campanhaId,
  }) async {
    if (!vendasHabilitadas) {
      AppSnackBar.aviso(
        context,
        'Este estabelecimento ainda está implantando o seu cardápio. Logo estará disponível para vendas.',
      );
      return;
    }
    if (clienteId == null || clienteId == 0) {
      await direcionarParaLogin(
        context,
        mensagem: 'Faça login para adicionar itens ao carrinho.',
      );
      return;
    }

    final chaveItem = _chaveItemCardapio(produto);
    if (produtosEmAlteracao.contains(chaveItem)) return;

    setState(() => produtosEmAlteracao.add(chaveItem));

    try {
      await apiService.adicionarAoCarrinho(
        clienteId: clienteId!,
        organizacaoId: widget.loja.organizacaoId,
        lojaId: widget.loja.id,
        produtoId: produto.produtoId,
        cardapioItemId: produto.cardapioItemId,
        quantidade: quantidade,
        observacao: observacao,
        beneficioResgateId: beneficioResgateId,
        campanhaId: campanhaId,
      );

      if (!mounted) return;
      await carregarQuantidadeCarrinho();

      if (!mounted) return;
      setState(() => quantidadesSelecionadas[chaveItem] = 1);
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
        setState(() => produtosEmAlteracao.remove(chaveItem));
      }
    }
  }

  Future<void> _girarRoleta(Produto produto) async {
    if (!vendasHabilitadas) return;
    if (clienteId == null || clienteId == 0) {
      await direcionarParaLogin(
        context,
        mensagem: 'Entre para girar a roleta.',
      );
      return;
    }
    final campanha = _roletasPorProduto[produto.produtoId];
    if (campanha == null) return;
    try {
      final premio = await apiService.girarRoletaProduto(
        campanhaId: int.parse('${campanha['campanha_id']}'),
        clienteId: clienteId!,
      );
      if (!mounted) return;
      final percentual = int.tryParse('${premio['percentual_desconto']}') ?? 0;
      final usarDesconto = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RoletaPremioDialog(
          produtoNome: produto.nmproduto,
          percentual: percentual,
        ),
      );
      if (!mounted || usarDesconto != true) return;
      await adicionarProdutoAoCarrinho(
        produto,
        quantidade: 1,
        beneficioResgateId: int.parse('${premio['resgate_id']}'),
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, apiService.mensagemErroAmigavel(e));
      }
    }
  }

  Future<void> resgatarCortesiaProduto(
    Produto produto,
    Map<String, dynamic>? campanha,
  ) async {
    if (!vendasHabilitadas) return;
    if (clienteId == null || clienteId == 0) {
      await direcionarParaLogin(
        context,
        mensagem: 'Entre para resgatar a cortesia.',
      );
      return;
    }
    if (campanha == null && produto.cardapioItemId == null) {
      AppSnackBar.erro(context, 'Esta cortesia não está disponível agora.');
      return;
    }

    final chaveItem = _chaveItemCardapio(produto);
    if (produtosEmAlteracao.contains(chaveItem)) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resgatar cortesia'),
        content: Text('Confirma o resgate da cortesia ${produto.nmproduto}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Resgatar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmou != true) return;

    setState(() => produtosEmAlteracao.add(chaveItem));

    try {
      if (campanha != null) {
        await apiService.resgatarCortesiaDaCampanha(
          campanhaId: int.parse('${campanha['campanha_id']}'),
          clienteId: clienteId!,
        );
      } else {
        await apiService.resgatarCortesiaProduto(
          clienteId: clienteId!,
          organizacaoId: widget.loja.organizacaoId,
          lojaId: widget.loja.id,
          cardapioItemId: produto.cardapioItemId!,
        );
      }
      CarteiraBadgeNotifier.atualizar();
      await carregarDados();
      if (!mounted) return;
      AppSnackBar.sucesso(context, 'Cortesia resgatada com sucesso.');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(context, apiService.mensagemErroAmigavel(e));
    } finally {
      if (mounted) {
        setState(() => produtosEmAlteracao.remove(chaveItem));
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
                    fontSize: 10,
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
                  ? Icons.local_drink_outlined
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
        iconeTitulo: Icons.local_drink_rounded,
        corIconeTitulo: Colors.amber,
        mostrarVoltar: true,
        mostrarSessao: false,
        mostrarCarrinho: vendasHabilitadas,
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
                if (!vendasHabilitadas)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          color: Colors.blue.shade800,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Este estabelecimento ainda está implantando o seu cardápio. Logo estará disponível para vendas.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
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
    final campanhaCortesia = _cortesiasPorProduto[produto.produtoId];
    final campanhaPacote = _pacotesPorProduto[produto.produtoId];
    final quantidadePacote =
        int.tryParse('${campanhaPacote?['qtitenspacote']}') ?? 0;
    final valorPacote = double.tryParse('${campanhaPacote?['vrpacote']}') ?? 0;
    final temPacote = quantidadePacote >= 2 && valorPacote > 0;
    final ehCortesiaLegada = precoAtual <= 0;
    final ehCortesia = campanhaCortesia != null || ehCortesiaLegada;
    final cortesiaBloqueadaParaCliente =
        campanhaCortesia?['disponivel_para_cliente'] == false;
    final cortesiaDisponivel = campanhaCortesia != null
        ? !cortesiaBloqueadaParaCliente
        : produto.cortesiaDisponivel == true;
    final cortesiasRestantes = campanhaCortesia == null
        ? produto.cortesiasRestantes ?? 0
        : int.tryParse('${campanhaCortesia['restantes']}') ?? 0;
    final cortesiasIlimitadas = campanhaCortesia?['restantes'] == null;
    final resgatandoCortesia = produtosEmAlteracao.contains(
      _chaveItemCardapio(produto),
    );

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
        child: SizedBox(
          height: temPacote ? 184 : 156,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _imagemProdutoCard(
                imagem: imagem,
                temDesconto: temDesconto,
                ehCortesia: ehCortesia,
                seloDesconto: seloDesconto,
                onTap: () => _abrirDetalhesProduto(produto),
              ),
              VerticalDivider(width: 1, color: Colors.grey.shade100),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
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
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ehCortesia
                                ? Text.rich(
                                    TextSpan(
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                      ),
                                      children: [
                                        const TextSpan(text: 'Cortesia: de '),
                                        TextSpan(
                                          text: ValueFormatters.moeda(
                                            produto.vrprecoprod,
                                          ),
                                          style: const TextStyle(
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                        const TextSpan(text: ' por '),
                                        TextSpan(
                                          text: ValueFormatters.moeda(0),
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
                                : temDesconto
                                ? Text.rich(
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
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                        const TextSpan(text: ' por '),
                                        TextSpan(
                                          text: ValueFormatters.moeda(
                                            precoAtual,
                                          ),
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
                                : Text(
                                    ValueFormatters.moeda(precoAtual),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                    ),
                                  ),
                          ),
                          _controleQuantidadeProduto(produto),
                        ],
                      ),

                      const SizedBox(height: 4),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            produto.dsproduto.trim().isNotEmpty
                                ? produto.dsproduto
                                : ' ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.2,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      if (ehCortesia) ...[
                        const SizedBox(height: 2),
                        Text(
                          cortesiaBloqueadaParaCliente
                              ? 'Você já possui uma cortesia válida deste produto'
                              : cortesiaDisponivel
                              ? cortesiasIlimitadas
                                    ? 'Cortesias disponíveis'
                                    : '$cortesiasRestantes ${cortesiasRestantes == 1 ? 'cortesia restante' : 'cortesias restantes'}'
                              : 'Cortesias esgotadas',
                          style: TextStyle(
                            color: cortesiaDisponivel
                                ? Colors.green.shade800
                                : Colors.red.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (_roletasPorProduto.containsKey(
                        produto.produtoId,
                      )) ...[
                        const SizedBox(height: 3),
                        InkWell(
                          onTap: vendasHabilitadas
                              ? () => _girarRoleta(produto)
                              : null,
                          child: Text(
                            '🎰 Girar roleta: 10% ou 20% OFF',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: vendasHabilitadas
                                  ? Colors.deepPurple.shade700
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                      if (temPacote) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Promoção: $quantidadePacote por ${ValueFormatters.moeda(valorPacote)}',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: Row(
                          children: [
                            if (temPacote) ...[
                              Expanded(
                                flex: 3,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      !vendasHabilitadas ||
                                          produtosEmAlteracao.contains(
                                            _chaveItemCardapio(produto),
                                          )
                                      ? null
                                      : () => adicionarProdutoAoCarrinho(
                                          produto,
                                          quantidade: 1,
                                          campanhaId: int.tryParse(
                                            '${campanhaPacote!['campanha_id']}',
                                          ),
                                        ),
                                  icon: const Icon(
                                    Icons.local_offer_rounded,
                                    size: 15,
                                  ),
                                  label: Text(
                                    '$quantidadePacote por ${ValueFormatters.moeda(valorPacote)}',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    disabledForegroundColor:
                                        Colors.grey.shade600,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (ehCortesia) ...[
                              Expanded(
                                flex: 3,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      !vendasHabilitadas ||
                                          resgatandoCortesia ||
                                          !cortesiaDisponivel
                                      ? null
                                      : () => resgatarCortesiaProduto(
                                          produto,
                                          campanhaCortesia,
                                        ),
                                  icon: resgatandoCortesia
                                      ? const SizedBox(
                                          width: 15,
                                          height: 15,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.redeem_rounded,
                                          size: 16,
                                        ),
                                  label: const Text('Resgatar cortesia'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    disabledForegroundColor:
                                        Colors.grey.shade600,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              flex: ehCortesia || temPacote ? 2 : 1,
                              child: ElevatedButton.icon(
                                onPressed:
                                    !vendasHabilitadas ||
                                        produtosEmAlteracao.contains(
                                          _chaveItemCardapio(produto),
                                        )
                                    ? null
                                    : () => adicionarProdutoAoCarrinho(
                                        produto,
                                        quantidade:
                                            quantidadesSelecionadas[_chaveItemCardapio(
                                              produto,
                                            )] ??
                                            1,
                                      ),
                                icon: const Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 17,
                                ),
                                label: Text(
                                  ehCortesia
                                      ? 'Comprar ${ValueFormatters.moeda(produto.vrprecoprod)}'
                                      : 'Carrinho',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  disabledForegroundColor: Colors.grey.shade600,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  void _abrirDetalhesProduto(Produto produto) {
    MainNavigationController.abrirTela(
      ProdutoCompartilhadoScreen(
        produtoId: produto.produtoId,
        lojaId: widget.loja.id,
      ),
    );
  }

  Widget _imagemProdutoCard({
    required String imagem,
    required bool temDesconto,
    required bool ehCortesia,
    required String seloDesconto,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 104,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imagem.isEmpty
                ? Container(
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.fastfood_outlined, size: 34),
                  )
                : ColoredBox(
                    color: Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.network(
                        imagem,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Container(
                          color: Colors.grey.shade100,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
            if (temDesconto)
              Positioned(
                left: 7,
                top: 7,
                child: _seloProduto(seloDesconto, Colors.red),
              ),
            if (ehCortesia)
              Positioned(
                left: 7,
                bottom: 7,
                child: _seloProduto('Cortesia', Colors.green.shade700),
              ),
          ],
        ),
      ),
    );
  }

  Widget _seloProduto(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _controleQuantidadeProduto(Produto produto) {
    final chaveItem = _chaveItemCardapio(produto);
    final quantidade = quantidadesSelecionadas[chaveItem] ?? 1;
    final alterando = produtosEmAlteracao.contains(chaveItem);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Diminuir quantidade',
            onPressed: vendasHabilitadas && !alterando && quantidade > 1
                ? () => setState(
                    () => quantidadesSelecionadas[chaveItem] = quantidade - 1,
                  )
                : null,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded, size: 19),
          ),
          SizedBox(
            width: 22,
            child: Center(
              child: alterando
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '$quantidade',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          IconButton(
            tooltip: 'Aumentar quantidade',
            onPressed: vendasHabilitadas && !alterando
                ? () => setState(
                    () => quantidadesSelecionadas[chaveItem] = quantidade + 1,
                  )
                : null,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _RoletaPremioDialog extends StatefulWidget {
  final String produtoNome;
  final int percentual;

  const _RoletaPremioDialog({
    required this.produtoNome,
    required this.percentual,
  });

  @override
  State<_RoletaPremioDialog> createState() => _RoletaPremioDialogState();
}

class _RoletaPremioDialogState extends State<_RoletaPremioDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotacao;
  var _concluida = false;

  @override
  void initState() {
    super.initState();
    const angulosPorPremio = <int, double>{
      0: 0,
      10: math.pi * 8 / 5,
      20: math.pi * 6 / 5,
      30: math.pi * 4 / 5,
      50: math.pi * 2 / 5,
    };
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    _rotacao = Tween<double>(
      begin: 0,
      end: (math.pi * 2 * 6) + (angulosPorPremio[widget.percentual] ?? 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _concluida = true);
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Roleta promocional'),
      content: SizedBox(
        width: 290,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: _rotacao,
                    builder: (_, child) =>
                        Transform.rotate(angle: _rotacao.value, child: child),
                    child: const _RoletaComPercentuais(),
                  ),
                  const Positioned(top: 0, child: _IndicadorRoleta()),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _concluida
                  ? 'Você ganhou ${widget.percentual}% de desconto!'
                  : 'Girando a roleta...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _concluida
                    ? Colors.green.shade700
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _concluida
                  ? 'Use agora em ${widget.produtoNome}. O prêmio expira em 20 minutos.'
                  : 'Aguarde o resultado do seu sorteio.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _concluida ? () => Navigator.pop(context, false) : null,
          child: const Text('Agora não'),
        ),
        ElevatedButton(
          onPressed: _concluida ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
          ),
          child: const Text('Usar desconto'),
        ),
      ],
    );
  }
}

class _RoletaComPercentuais extends StatelessWidget {
  const _RoletaComPercentuais();

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
      color: Colors.white,
      fontSize: 23,
      fontWeight: FontWeight.w900,
      shadows: [
        Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 2)),
      ],
    );
    return SizedBox(
      width: 245,
      height: 245,
      child: Stack(
        children: const [
          Positioned.fill(
            child: Image(
              image: AssetImage(
                'assets/images/roleta_promocional_sem_ponteiro.png',
              ),
              fit: BoxFit.contain,
            ),
          ),
          Align(
            alignment: Alignment(0, -0.48),
            child: Text('0%', style: estilo),
          ),
          Align(
            alignment: Alignment(0.52, -0.15),
            child: Text('10%', style: estilo),
          ),
          Align(
            alignment: Alignment(0.33, 0.48),
            child: Text('20%', style: estilo),
          ),
          Align(
            alignment: Alignment(-0.33, 0.48),
            child: Text('30%', style: estilo),
          ),
          Align(
            alignment: Alignment(-0.52, -0.15),
            child: Text('50%', style: estilo),
          ),
        ],
      ),
    );
  }
}

class _IndicadorRoleta extends StatelessWidget {
  const _IndicadorRoleta();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(50, 43),
      painter: _IndicadorRoletaPainter(),
    );
  }
}

class _IndicadorRoletaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sombra = Path()
      ..moveTo(2, 2)
      ..lineTo(size.width - 2, 2)
      ..lineTo(size.width / 2, size.height - 1)
      ..close();
    canvas.drawShadow(sombra, Colors.black, 4, true);
    canvas.drawPath(
      sombra,
      Paint()
        ..color = const Color(0xff3d2600)
        ..style = PaintingStyle.fill,
    );

    final ponteiro = Path()
      ..moveTo(6, 5)
      ..lineTo(size.width - 6, 5)
      ..lineTo(size.width / 2, size.height - 6)
      ..close();
    canvas.drawPath(
      ponteiro,
      Paint()
        ..color = const Color(0xffffc928)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      ponteiro,
      Paint()
        ..color = const Color(0xfffff0b0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
