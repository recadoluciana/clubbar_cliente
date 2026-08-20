import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../models/categoria.dart';
import '../../models/loja.dart';
import '../../models/produto.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/cart_badge_notifier.dart';
import '../../utils/value_formatters.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../services/main_navigation_controller.dart';
import '../detalhe_loja/detalhe_loja_screen.dart';
import 'produto_compartilhado_screen.dart';
import '../agenda/agenda_eventos_screen.dart';
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

  Future<File?> gerarArteCompartilhamento(Produto produto) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(1080, 1350);

      final paint = Paint();

      paint.color = Colors.white;
      canvas.drawRect(Offset.zero & size, paint);

      paint.color = Colors.black;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 180), paint);

      final tituloClubbar = TextPainter(
        text: const TextSpan(
          text: 'CLUBBAR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 1000);

      tituloClubbar.paint(canvas, Offset((1080 - tituloClubbar.width) / 2, 60));

      final fotoUrl = produto.urlfotoproduto ?? '';

      if (fotoUrl.isNotEmpty) {
        final response = await http.get(Uri.parse(fotoUrl));

        if (response.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(
            response.bodyBytes,
            targetWidth: 1080,
            targetHeight: 650,
          );

          final frame = await codec.getNextFrame();

          canvas.drawImageRect(
            frame.image,
            Rect.fromLTWH(
              0,
              0,
              frame.image.width.toDouble(),
              frame.image.height.toDouble(),
            ),
            const Rect.fromLTWH(0, 180, 1080, 650),
            Paint(),
          );
        }
      }

      if (produto.descontoativo) {
        paint.color = Colors.red;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(60, 860, 310, 70),
            const Radius.circular(18),
          ),
          paint,
        );

        final descontoTexto = TextPainter(
          text: TextSpan(
            text: 'Promoção',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 280);

        descontoTexto.paint(canvas, const Offset(85, 875));
      }

      final nomeProduto = TextPainter(
        text: TextSpan(
          text: produto.nmproduto,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 58,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      )..layout(maxWidth: 960);

      nomeProduto.paint(canvas, const Offset(60, 960));

      final preco = produto.descontoativo
          ? ValueFormatters.moeda(produto.vrprecofinal)
          : ValueFormatters.moeda(produto.vrprecoprod);

      final precoTexto = TextPainter(
        text: TextSpan(
          text: preco,
          style: const TextStyle(
            color: Colors.green,
            fontSize: 64,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 960);

      precoTexto.paint(canvas, const Offset(60, 1100));

      final lojaTexto = TextPainter(
        text: TextSpan(
          text: '📍 ${widget.loja.nome}',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 38,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: 960);

      lojaTexto.paint(canvas, const Offset(60, 1200));

      paint.color = Colors.amber;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(60, 1265, 960, 55),
          const Radius.circular(16),
        ),
        paint,
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/clubbar_produto_${produto.produtoId}.png');

      await file.writeAsBytes(byteData.buffer.asUint8List());

      return file;
    } catch (e) {
      return null;
    }
  }

  Future<void> compartilharProduto(Produto produto) async {
    final link =
        'https://app.clubbar.com.br/?loja_id=${widget.loja.id}&produto_id=${produto.produtoId}';

    final texto = produto.descontoativo
        ? '🔥 PROMOÇÃO NO CLUBBAR\n\n'
              ' ${produto.nmproduto}\n\n'
              '💲 De ${ValueFormatters.moeda(produto.vrprecoprod)}\n'
              '✅ Por ${ValueFormatters.moeda(produto.vrprecofinal)}\n\n'
              '📍 ${widget.loja.nome}\n\n'
              'Peça agora pelo Clubbar 👇\n$link'
        : '🍽️ ${produto.nmproduto}\n\n'
              '💰 ${ValueFormatters.moeda(produto.vrprecoprod)}\n\n'
              '📍 ${widget.loja.nome}\n\n'
              'Peça agora pelo Clubbar 👇\n$link';

    final arte = await gerarArteCompartilhamento(produto);

    if (arte != null) {
      await Share.shareXFiles([XFile(arte.path)], text: texto);
    } else {
      await Share.share(texto);
    }
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

  Future<void> abrirDialogObservacao(Produto produto) async {
    final controller = TextEditingController();

    if (clienteId == null || clienteId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faça login para adicionar itens ao carrinho'),
        ),
      );
      return;
    }

    final resultado = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF6F6F6), // mesmo fundo da tela
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            produto.nmproduto,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ex.: sem cebola, bem passado, tirar gelo...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context, null),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFF6F6F6),
                foregroundColor: Colors.black,
              ),
              child: const Text('Cancelar'),
            ),

            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
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
        errorBuilder: (_, _, _) => Container(
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            categoriaSelecionadaId = categoria.id;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 78,
          height: 70,
          decoration: BoxDecoration(
            color: selecionada ? Colors.amber : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selecionada ? Colors.amber : Colors.grey.shade300,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CategoriaIconUtils.porNome(categoria.nome),
                  color: selecionada ? Colors.black : Colors.grey.shade700,
                  size: 22,
                ),
                const SizedBox(height: 5),
                Text(
                  categoria.nome,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
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

      appBar: ClubbarAppBar(
        mostrarVoltar: true,
        onVoltar: () {
          if (widget.onVoltar != null) {
            widget.onVoltar!();
            return;
          }

          if (Navigator.canPop(context)) {
            Navigator.pop(context);
            return;
          }

          MainNavigationController.abrirTela(
            DetalheLojaScreen(loja: widget.loja),
          );
        },
      ),

      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro != null
          ? _erroWidget()
          : Column(
              children: [
                ClubbarPageHeader(
                  titulo: widget.loja.nome,
                  subtitulo: 'Cardápio e bebidas',
                  icone: Icons.restaurant_menu_rounded,
                  trailing: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AgendaEventosScreen(loja: widget.loja),
                        ),
                      );
                    },
                    icon: const Icon(Icons.event, size: 18),
                    label: const Text('Agenda'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
                      height: 82,
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
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        if (produtosFiltrados.isEmpty)
                          _estadoVazio()
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: produtosFiltrados.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 270,
                                ),
                            itemBuilder: (context, index) {
                              return _cardProdutoGrade(
                                produtosFiltrados[index],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _cardProdutoGrade(Produto produto) {
    final temDesconto = produto.descontoativo;

    final precoAtual = temDesconto ? produto.vrprecofinal : produto.vrprecoprod;

    final seloDesconto = produto.tipodesconto.toUpperCase() == 'PERCENTUAL'
        ? '${produto.vrdesconto.toStringAsFixed(0)}% OFF'
        : '${ValueFormatters.moeda(produto.vrdesconto)} OFF';

    final imagem = produto.urlfotoproduto ?? '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProdutoCompartilhadoScreen(produtoId: produto.produtoId),
            ),
          );
        },
        child: SizedBox(
          height: 270,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 125,
                    child: imagem.isEmpty
                        ? Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.fastfood_outlined,
                              size: 38,
                            ),
                          )
                        : Image.network(
                            imagem,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 36,
                                ),
                              );
                            },
                          ),
                  ),

                  if (temDesconto)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          seloDesconto,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    right: 8,
                    top: 8,
                    child: Material(
                      color: Colors.white.withOpacity(0.92),
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        onPressed: () => compartilharProduto(produto),
                        tooltip: 'Compartilhar produto',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.ios_share_rounded, size: 19),
                      ),
                    ),
                  ),
                ],
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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

                      const SizedBox(height: 3),

                      if (temDesconto) ...[
                        Text(
                          ValueFormatters.moeda(produto.vrprecoprod),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],

                      const SizedBox(height: 5),
                      Text(
                        ValueFormatters.moeda(precoAtual),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: temDesconto
                              ? Colors.green.shade700
                              : Colors.black,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        produto.dsproduto.trim().isEmpty
                            ? 'sem descrição'
                            : produto.dsproduto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                        ),
                      ),

                      const Spacer(),

                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: ElevatedButton.icon(
                          onPressed: () => abrirDialogObservacao(produto),
                          icon: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 16,
                          ),
                          label: const Text(
                            'Carrinho',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
    );
  }
}
