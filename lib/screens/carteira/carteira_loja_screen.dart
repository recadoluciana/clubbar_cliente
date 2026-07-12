import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/carteira_badge_notifier.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_page_header.dart';
import '../../utils/value_formatters.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../../services/api_service.dart';

import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

class CarteiraLojaScreen extends StatefulWidget {
  final String nomeLoja;
  final String logoLoja;
  final String nomeCliente;
  final List<Map<String, dynamic>> itens;
  final Future<List<Map<String, dynamic>>> Function()? onAtualizar;
  final VoidCallback onVoltar;

  const CarteiraLojaScreen({
    super.key,
    required this.nomeLoja,
    required this.logoLoja,
    required this.nomeCliente,
    required this.itens,
    required this.onAtualizar,
    required this.onVoltar,
  });

  @override
  State<CarteiraLojaScreen> createState() => _CarteiraLojaScreenState();
}

class _CarteiraLojaScreenState extends State<CarteiraLojaScreen> {
  late List<Map<String, dynamic>> itensTela;

  @override
  void initState() {
    super.initState();
    itensTela = List<Map<String, dynamic>>.from(widget.itens);
  }

  bool _isIngresso(Map<String, dynamic> item) {
    return (item['idtipoproduto'] ?? '').toString().toUpperCase() == 'I';
  }

  String _buildImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$ApiService. baseUrl$path';
  }

  String _montarDadosQr(Map<String, dynamic> item) {
    final token = (item['qrtokenitvenda'] ?? '').toString().trim();

    if (token.isEmpty) {
      return '';
    }

    return 'CLUBBAR-PRODUTO:$token';
  }

  Future<ui.Image?> _carregarImagemProduto(Map<String, dynamic> item) async {
    try {
      final url = _buildImageUrl((item['urlfotoproduto'] ?? '').toString());

      if (url.isEmpty) {
        return null;
      }

      final resposta = await http.get(Uri.parse(url));

      if (resposta.statusCode != 200) {
        return null;
      }

      final codec = await ui.instantiateImageCodec(
        resposta.bodyBytes,
        targetWidth: 900,
        targetHeight: 520,
      );

      final frame = await codec.getNextFrame();

      return frame.image;
    } catch (_) {
      return null;
    }
  }

  void _desenharTexto(
    Canvas canvas, {
    required String texto,
    required Offset posicao,
    required double larguraMaxima,
    required double tamanho,
    required Color cor,
    FontWeight peso = FontWeight.normal,
    int maxLines = 1,
    TextAlign alinhamento = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          color: cor,
          fontSize: tamanho,
          fontWeight: peso,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: alinhamento,
      maxLines: maxLines,
      ellipsis: '...',
    )..layout(maxWidth: larguraMaxima);

    painter.paint(canvas, posicao);
  }

  Future<Uint8List?> _gerarImagemPresente(Map<String, dynamic> item) async {
    try {
      const largura = 1080.0;
      const altura = 1600.0;

      const tamanhoQr = 600.0;
      const margemQr = 45.0;
      const tamanhoAreaQr = tamanhoQr + (margemQr * 2);

      final dadosQr = _montarDadosQr(item).trim();

      if (dadosQr.isEmpty) {
        return null;
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();

      // Fundo geral
      paint.color = const Color(0xFFF6F6F6);

      canvas.drawRect(const Rect.fromLTWH(0, 0, largura, altura), paint);

      // Cabeçalho preto
      paint.color = Colors.black;

      canvas.drawRect(const Rect.fromLTWH(0, 0, largura, 155), paint);

      _desenharTexto(
        canvas,
        texto: 'CLUBBAR',
        posicao: const Offset(0, 44),
        larguraMaxima: largura,
        tamanho: 54,
        cor: Colors.white,
        peso: FontWeight.w900,
        alinhamento: TextAlign.center,
      );

      // Cartão principal
      paint.color = Colors.white;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(50, 190, 980, 1350),
          const Radius.circular(42),
        ),
        paint,
      );

      // Faixa do presente
      paint.color = Colors.amber;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(90, 230, 900, 82),
          const Radius.circular(22),
        ),
        paint,
      );

      _desenharTexto(
        canvas,
        texto: 'Você ganhou um presente!',
        posicao: const Offset(90, 251),
        larguraMaxima: 900,
        tamanho: 36,
        cor: Colors.black,
        peso: FontWeight.w900,
        alinhamento: TextAlign.center,
      );

      // Foto do produto
      final imagemProduto = await _carregarImagemProduto(item);

      final areaFoto = RRect.fromRectAndRadius(
        const Rect.fromLTWH(90, 345, 900, 300),
        const Radius.circular(28),
      );

      canvas.save();
      canvas.clipRRect(areaFoto);

      if (imagemProduto != null) {
        final origem = Rect.fromLTWH(
          0,
          0,
          imagemProduto.width.toDouble(),
          imagemProduto.height.toDouble(),
        );

        canvas.drawImageRect(
          imagemProduto,
          origem,
          areaFoto.outerRect,
          Paint()..filterQuality = FilterQuality.high,
        );
      } else {
        paint.color = const Color(0xFFFFF2C7);

        canvas.drawRect(areaFoto.outerRect, paint);

        _desenharTexto(
          canvas,
          texto: 'PRESENTE CLUBBAR',
          posicao: const Offset(90, 465),
          larguraMaxima: 900,
          tamanho: 42,
          cor: Colors.black,
          peso: FontWeight.w800,
          alinhamento: TextAlign.center,
        );
      }

      canvas.restore();

      final nomeProduto = (item['nmproduto'] ?? 'Produto Clubbar')
          .toString()
          .trim();

      // Nome do produto
      _desenharTexto(
        canvas,
        texto: nomeProduto,
        posicao: const Offset(90, 680),
        larguraMaxima: 900,
        tamanho: 44,
        cor: Colors.black,
        peso: FontWeight.w900,
        maxLines: 2,
        alinhamento: TextAlign.center,
      );

      // Nome da loja
      _desenharTexto(
        canvas,
        texto: widget.nomeLoja,
        posicao: const Offset(90, 785),
        larguraMaxima: 900,
        tamanho: 29,
        cor: Colors.grey.shade800,
        peso: FontWeight.w700,
        alinhamento: TextAlign.center,
      );

      // Quem enviou
      if (widget.nomeCliente.trim().isNotEmpty) {
        _desenharTexto(
          canvas,
          texto: 'Presente de ${widget.nomeCliente}',
          posicao: const Offset(90, 830),
          larguraMaxima: 900,
          tamanho: 25,
          cor: Colors.grey.shade700,
          peso: FontWeight.w600,
          alinhamento: TextAlign.center,
        );
      }

      // Área branca externa do QR Code
      const areaBrancaQr = Rect.fromLTWH(
        (largura - tamanhoAreaQr) / 2,
        885,
        tamanhoAreaQr,
        tamanhoAreaQr,
      );

      paint.color = Colors.white;

      canvas.drawRect(areaBrancaQr, paint);

      // Geração do QR Code
      final qrPainter = QrPainter(
        data: dadosQr,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: false,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      final qrData = await qrPainter.toImageData(
        tamanhoQr,
        format: ui.ImageByteFormat.png,
      );

      if (qrData == null) {
        return null;
      }

      final qrCodec = await ui.instantiateImageCodec(
        qrData.buffer.asUint8List(),
        targetWidth: tamanhoQr.toInt(),
        targetHeight: tamanhoQr.toInt(),
      );

      final qrFrame = await qrCodec.getNextFrame();

      const areaQr = Rect.fromLTWH(
        (largura - tamanhoQr) / 2,
        885 + margemQr,
        tamanhoQr,
        tamanhoQr,
      );

      final paintQr = Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none;

      canvas.drawImageRect(
        qrFrame.image,
        Rect.fromLTWH(
          0,
          0,
          qrFrame.image.width.toDouble(),
          qrFrame.image.height.toDouble(),
        ),
        areaQr,
        paintQr,
      );

      // Orientação
      _desenharTexto(
        canvas,
        texto: 'Apresente este QR Code ao atendente',
        posicao: const Offset(90, 1510),
        larguraMaxima: 900,
        tamanho: 22,
        cor: Colors.grey.shade700,
        peso: FontWeight.w700,
        alinhamento: TextAlign.center,
      );

      final picture = recorder.endRecording();

      final imagemFinal = await picture.toImage(
        largura.toInt(),
        altura.toInt(),
      );

      final dados = await imagemFinal.toByteData(
        format: ui.ImageByteFormat.png,
      );

      return dados?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Erro ao gerar imagem do presente: $e');
      return null;
    }
  }

  Future<void> _compartilharPresente(Map<String, dynamic> item) async {
    final itvendaId = int.tryParse('${item['itvenda_id'] ?? 0}') ?? 0;

    if (itvendaId == 0) {
      AppSnackBar.erro(
        context,
        'Não foi possível identificar este produto. Item venda id inválido.',
      );
      return;
    }

    AppSnackBar.info(context, 'Preparando o presente...');

    final imagem = await _gerarImagemPresente(item);

    if (!mounted) return;

    if (imagem == null) {
      AppSnackBar.erro(
        context,
        'Não foi possível gerar a imagem do presente. Imagem inválida.',
      );
      return;
    }

    final nomeProduto = (item['nmproduto'] ?? 'Presente Clubbar').toString();

    final texto =
        '🎁 Você ganhou um presente pelo Clubbar!\n\n'
        '$nomeProduto\n'
        '📍 ${widget.nomeLoja}\n\n'
        'Apresente o QR Code da imagem ao atendente.';

    try {
      await Share.shareXFiles(
        [
          XFile.fromData(
            imagem,
            name: 'presente_clubbar_$itvendaId.png',
            mimeType: 'image/png',
          ),
        ],
        text: texto,
        subject: 'Presente Clubbar',
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, 'Não foi possível compartilhar o presente.');
    }
  }

  Future<void> _confirmarCompartilhamento(Map<String, dynamic> item) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF6F6F6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(Icons.card_giftcard_rounded, color: Colors.amber),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Enviar como presente',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'Será criada uma imagem com a foto do produto e o QR Code.\n\n'
            'O produto continuará aparecendo na sua carteira, mas o mesmo '
            'QR Code poderá ser usado pela pessoa presenteada.\n\n'
            'Quem apresentar o QR Code primeiro utilizará o produto.',
            style: TextStyle(height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Compartilhar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        );
      },
    );

    if (confirmado != true) {
      return;
    }

    await _compartilharPresente(item);
  }

  Future<void> _abrirQrOuRetirada(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final codigo = (item['itvenda_id'] ?? '').toString();

    final qrData = _montarDadosQr(item);

    if (codigo.isEmpty) {
      AppSnackBar.erro(context, 'QR Code não disponível para este item.');
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Retirada do produto',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  (item['nmproduto'] ?? '').toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if ((item['dsobsitvenda'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (item['dsobsitvenda'] ?? '').toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Apresente este QR Code para o atendente.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                QrImageView(
                  data: qrData,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // atualizar itens e badge após retirada ou fechamento do qr
    if (widget.onAtualizar != null) {
      final novosItens = await widget.onAtualizar!();

      CarteiraBadgeNotifier.atualizar();

      if (!mounted) return;

      setState(() {
        itensTela = novosItens;
      });
    }
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

  Widget _itemCard(BuildContext context, Map<String, dynamic> item) {
    final obs = (item['dsobsitvenda'] ?? '').toString();
    final validade = (item['dtexpiraitvenda_fmt'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _abrirQrOuRetirada(context, item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _imagemItem(item),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item['nmproduto'] ?? '').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _chip('Qtd: ${item['qtitvenda'] ?? 0}'),
                              _chip(
                                'Valor: ${ValueFormatters.moeda(double.tryParse('${item['vrunititvenda']}') ?? 0)}',
                              ),
                              if (validade.isNotEmpty)
                                _chip('Validade: $validade'),
                            ],
                          ),

                          if (obs.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Observação: $obs',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () => _abrirQrOuRetirada(context, item),
                          icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                          label: const Text(
                            'Usar',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF7A5A00),
                            side: const BorderSide(color: Color(0xFFE0C36A)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmarCompartilhamento(item),
                          icon: const Icon(
                            Icons.card_giftcard_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Presentear',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
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

  Widget _imagemItem(Map<String, dynamic> item) {
    final url = _buildImageUrl((item['urlfotoproduto'] ?? '').toString());

    if (url.isEmpty) {
      return _placeholderItem(item);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        url,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholderItem(item),
      ),
    );
  }

  Widget _placeholderItem(Map<String, dynamic> item) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        _isIngresso(item)
            ? Icons.confirmation_number_outlined
            : Icons.local_bar_outlined,
        color: Colors.amber.shade800,
        size: 30,
      ),
    );
  }

  Widget _logoLoja() {
    if (widget.logoLoja.isEmpty) {
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
        widget.logoLoja,
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

  Widget _estadoVazio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          const Text(
            'Nenhum produto disponível',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Não há produtos disponíveis para retirada nesta loja.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalUnidades = itensTela.fold<int>(0, (total, item) {
      final quantidade = int.tryParse('${item['qtitvenda'] ?? 0}') ?? 0;

      return total + quantidade;
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: ClubbarAppBar(mostrarVoltar: true, onVoltar: widget.onVoltar),

      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: 'Carteira de Produtos',
            subtitulo:
                '${widget.nomeLoja} • $totalUnidades item(ns) disponível(is)',
            icone: Icons.inventory_2_rounded,
            imagemUrl: widget.logoLoja,
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (widget.onAtualizar == null) return;

                final novosItens = await widget.onAtualizar!();

                CarteiraBadgeNotifier.atualizar();

                if (!mounted) return;

                setState(() {
                  itensTela = novosItens;
                });
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  if (itensTela.isEmpty)
                    _estadoVazio()
                  else
                    ...itensTela.map((item) => _itemCard(context, item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
