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
import '../../widgets/clubbar_app_bar.dart';
import '../../services/main_navigation_controller.dart';
import '../detalhe_loja/detalhe_loja_screen.dart';
import 'produto_compartilhado_screen.dart';

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

  @override
  void initState() {
    super.initState();
    carregarDados();
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

        final desconto = TextPainter(
          text: const TextSpan(
            text: 'PROMOÇÃO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 300);

        desconto.paint(canvas, const Offset(92, 876));
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
                backgroundColor: Colors.green,
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ProdutoCompartilhadoScreen(produtoId: produto.produtoId),
              ),
            );
          },
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
                        produto.dsproduto.isEmpty ? '' : produto.dsproduto,
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
                          ValueFormatters.moeda(produto.vrprecoprod),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ValueFormatters.moeda(produto.vrprecofinal),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.green,
                          ),
                        ),
                      ] else
                        Text(
                          ValueFormatters.moeda(produto.vrprecoprod),
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
                  children: [
                    IconButton(
                      onPressed: () => compartilharProduto(produto),
                      icon: const Icon(Icons.share_outlined),
                      tooltip: 'Compartilhar produto',
                    ),
                    IconButton(
                      onPressed: () => abrirDialogObservacao(produto),
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

      appBar: ClubbarAppBar(
        mostrarVoltar: true,
        onVoltar:
            widget.onVoltar ??
            () {
              MainNavigationController.abrirTela(
                DetalheLojaScreen(loja: widget.loja),
              );
            },
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.loja.nome,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Cardápio',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (categorias.isEmpty)
                    const Text('Nenhum cardápio disponível.')
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categorias.map(_chipCategoria).toList(),
                      ),
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
