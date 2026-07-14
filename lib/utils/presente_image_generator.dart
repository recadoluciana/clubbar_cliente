import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

class PresenteImageGenerator {
  static Future<Uint8List?> gerar({
    required String tipo,
    required String nomeItem,
    required String nomeLoja,
    required String nomeRemetente,
    required String imagemUrl,
    required String dadosQr,
    String validade = '',
    String urlApp = 'https://clubbar.com.br/app',
    String urlWeb = 'https://app.clubbar.com.br',
  }) async {
    try {
      const largura = 1080.0;
      const altura = 1940.0;

      final tipoNormalizado = tipo.trim().toUpperCase();
      final ehIngresso = tipoNormalizado == 'I';

      final nomeItemFinal = nomeItem.trim().isEmpty
          ? (ehIngresso ? 'Ingresso Clubbar' : 'Produto Clubbar')
          : nomeItem.trim();

      final nomeLojaFinal = nomeLoja.trim().isEmpty
          ? 'Estabelecimento Clubbar'
          : nomeLoja.trim();

      final qrPrincipal = dadosQr.trim();

      if (qrPrincipal.isEmpty) {
        debugPrint(
          '[PRESENTE] Não foi possível gerar a imagem: dados do QR vazios.',
        );
        return null;
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();

      _desenharFundo(
        canvas: canvas,
        paint: paint,
        largura: largura,
        altura: altura,
      );

      _desenharCabecalho(canvas: canvas, paint: paint);

      const areaCartao = Rect.fromLTWH(44, 176, 992, 1718);

      paint.color = Colors.white;

      canvas.drawRRect(
        RRect.fromRectAndRadius(areaCartao, const Radius.circular(42)),
        paint,
      );

      _desenharFaixaPresente(canvas: canvas, paint: paint);

      await _desenharImagemPrincipal(
        canvas: canvas,
        paint: paint,
        imagemUrl: imagemUrl,
        ehIngresso: ehIngresso,
      );

      _desenharDadosPresente(
        canvas: canvas,
        nomeItem: nomeItemFinal,
        nomeLoja: nomeLojaFinal,
        nomeRemetente: nomeRemetente,
        validade: validade,
      );

      await _desenharQrPrincipal(
        canvas: canvas,
        paint: paint,
        dadosQr: qrPrincipal,
      );

      _desenharDivisor(canvas: canvas, paint: paint, y: 1450);

      _desenharMarketing(canvas: canvas);

      await _desenharAreaDivulgacao(
        canvas: canvas,
        paint: paint,
        urlApp: urlApp,
        urlWeb: urlWeb,
      );

      _desenharRodape(canvas: canvas, urlWeb: urlWeb);

      final picture = recorder.endRecording();
      final imagemFinal = await picture.toImage(
        largura.toInt(),
        altura.toInt(),
      );

      final dados = await imagemFinal.toByteData(
        format: ui.ImageByteFormat.png,
      );

      return dados?.buffer.asUint8List();
    } catch (e, stackTrace) {
      debugPrint('[PRESENTE] Erro ao gerar imagem: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static void _desenharFundo({
    required Canvas canvas,
    required Paint paint,
    required double largura,
    required double altura,
  }) {
    paint.color = const Color(0xFFF2F2F2);
    canvas.drawRect(Rect.fromLTWH(0, 0, largura, altura), paint);
  }

  static void _desenharCabecalho({
    required Canvas canvas,
    required Paint paint,
  }) {
    const areaCabecalho = Rect.fromLTWH(0, 0, 1080, 145);

    paint.color = Colors.black;
    canvas.drawRect(areaCabecalho, paint);

    _desenharLinhaCentralizadaComIcone(
      canvas,
      area: areaCabecalho,
      icone: Icons.card_giftcard_rounded, // presentinho estilizado
      texto: 'CLUBBAR',
      tamanhoIcone: 66,
      tamanhoTexto: 56,
      cor: Colors.white,
      peso: FontWeight.w900,
      espacamento: 14,
    );
  }

  static void _desenharFaixaPresente({
    required Canvas canvas,
    required Paint paint,
  }) {
    const areaFaixa = Rect.fromLTWH(84, 215, 912, 86);

    paint.color = Colors.amber;
    canvas.drawRRect(
      RRect.fromRectAndRadius(areaFaixa, const Radius.circular(22)),
      paint,
    );

    _desenharLinhaCentralizadaComIcone(
      canvas,
      area: areaFaixa,
      icone: Icons.card_giftcard_rounded,
      texto: 'Você recebeu um presente!',
      tamanhoIcone: 40,
      tamanhoTexto: 36,
      cor: Colors.black,
      peso: FontWeight.w900,
      espacamento: 13,
    );
  }

  static Future<void> _desenharImagemPrincipal({
    required Canvas canvas,
    required Paint paint,
    required String imagemUrl,
    required bool ehIngresso,
  }) async {
    const areaFotoRect = Rect.fromLTWH(84, 328, 912, 350);

    final areaFoto = RRect.fromRectAndRadius(
      areaFotoRect,
      const Radius.circular(28),
    );

    final imagem = await _carregarImagem(imagemUrl);

    canvas.save();
    canvas.clipRRect(areaFoto);

    paint.color = const Color(0xFFF7F7F7);
    canvas.drawRect(areaFotoRect, paint);

    if (imagem != null) {
      _desenharImagemContain(
        canvas: canvas,
        imagem: imagem,
        destino: areaFotoRect,
      );
    } else {
      paint.color = const Color(0xFFFFF2C7);
      canvas.drawRect(areaFotoRect, paint);

      _desenharTextoCentralizadoNaArea(
        canvas,
        texto: ehIngresso ? 'INGRESSO CLUBBAR' : 'PRESENTE CLUBBAR',
        area: areaFotoRect,
        tamanho: 42,
        cor: Colors.black,
        peso: FontWeight.w800,
      );
    }

    canvas.restore();

    canvas.drawRRect(
      areaFoto,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFE3E3E3),
    );
  }

  static void _desenharDadosPresente({
    required Canvas canvas,
    required String nomeItem,
    required String nomeLoja,
    required String nomeRemetente,
    required String validade,
  }) {
    _desenharTexto(
      canvas,
      texto: nomeItem,
      posicao: const Offset(84, 710),
      larguraMaxima: 912,
      tamanho: 43,
      cor: Colors.black,
      peso: FontWeight.w900,
      alinhamento: TextAlign.center,
    );

    _desenharTexto(
      canvas,
      texto: nomeLoja,
      posicao: const Offset(84, 760),
      larguraMaxima: 912,
      tamanho: 40,
      cor: Colors.black87,
      peso: FontWeight.w900,
      alinhamento: TextAlign.center,
    );

    if (nomeRemetente.trim().isNotEmpty) {
      _desenharTexto(
        canvas,
        texto: 'Presente de ${nomeRemetente.trim()}',
        posicao: const Offset(84, 810),
        larguraMaxima: 912,
        tamanho: 32,
        cor: Colors.blue,
        peso: FontWeight.w800,
        alinhamento: TextAlign.center,
      );
    }

    _desenharTexto(
      canvas,
      texto: validade.trim().isEmpty ? 'xxx' : 'Válido até ${validade.trim()}',
      posicao: const Offset(84, 850),
      larguraMaxima: 912,
      tamanho: 32,
      cor: Colors.red,
      peso: FontWeight.w800,
      alinhamento: TextAlign.center,
    );

    _desenharTexto(
      canvas,
      texto: 'Apresente este QR Code para o atendende',
      posicao: const Offset(84, 890),
      larguraMaxima: 912,
      tamanho: 30,
      cor: Colors.red,
      peso: FontWeight.w900,
      alinhamento: TextAlign.center,
    );
  }

  static Future<void> _desenharQrPrincipal({
    required Canvas canvas,
    required Paint paint,
    required String dadosQr,
  }) async {
    const tamanhoQr = 300.0;
    //350.0;
    const margemQr = 30.0;
    const tamanhoAreaQr = tamanhoQr + (margemQr * 2);

    const areaBrancaQr = Rect.fromLTWH(
      (1080 - tamanhoAreaQr) / 2,
      960 + margemQr,
      tamanhoAreaQr,
      tamanhoAreaQr,
    );

    paint.color = Colors.white;
    canvas.drawRect(areaBrancaQr, paint);

    final qrImage = await _gerarQrImage(conteudo: dadosQr, tamanho: tamanhoQr);

    if (qrImage == null) {
      throw Exception('Não foi possível gerar o QR Code principal.');
    }

    const areaQr = Rect.fromLTWH(
      (1080 - tamanhoQr) / 2,
      930 + margemQr,
      tamanhoQr,
      tamanhoQr,
    );

    canvas.drawImageRect(
      qrImage,
      Rect.fromLTWH(0, 0, qrImage.width.toDouble(), qrImage.height.toDouble()),
      areaQr,
      Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none,
    );
  }

  static void _desenharDivisor({
    required Canvas canvas,
    required Paint paint,
    required double y,
  }) {
    paint
      ..color = const Color(0xFFE2E2E2)
      ..strokeWidth = 2;

    canvas.drawLine(Offset(110, y), Offset(970, y), paint);
  }

  static void _desenharMarketing({required Canvas canvas}) {
    _desenharTexto(
      canvas,
      texto: 'Gostou deste presente?',
      posicao: const Offset(84, 1300),
      larguraMaxima: 912,
      tamanho: 36,
      cor: Colors.black,
      peso: FontWeight.w900,
      alinhamento: TextAlign.center,
    );

    _desenharTexto(
      canvas,
      texto: 'https://app.clubbar.com.br',
      posicao: const Offset(120 + 362, 1300),
      larguraMaxima: 912,
      tamanho: 36,
      cor: Colors.black,
      peso: FontWeight.w900,
      alinhamento: TextAlign.center,
    );

    _desenharTexto(
      canvas,
      texto:
          'Conheça o aplicativo Clubbar, para bares e casas noturnas.\nBaixe o app e aproveite promoções, descontos e benefícios exclusivos.',
      posicao: const Offset(118, 1350),
      larguraMaxima: 844,
      tamanho: 23,
      cor: Colors.black,
      peso: FontWeight.w600,
      maxLines: 3,
      alinhamento: TextAlign.center,
    );
  }

  static Future<void> _desenharAreaDivulgacao({
    required Canvas canvas,
    required Paint paint,
    required String urlApp,
    required String urlWeb,
  }) async {
    const tamanhoQr = 130.0;
    const margem = 12.0;

    final qrApp = await _gerarQrImage(
      conteudo: urlApp.trim(),
      tamanho: tamanhoQr,
    );

    final qrWeb = await _gerarQrImage(
      conteudo: urlWeb.trim(),
      tamanho: tamanhoQr,
    );

    const areaApp = Rect.fromLTWH(115, 1450, 365, 220);
    const areaWeb = Rect.fromLTWH(600, 1450, 365, 220);

    _desenharCardDivulgacao(
      canvas: canvas,
      paint: paint,
      area: areaApp,
      titulo: 'Baixe o App',
      subtitulo: ' ',
      icone: Icons.download_rounded,
      qrImage: qrApp,
      tamanhoQr: tamanhoQr,
      margem: margem,
      fundo: Colors.black,
      corTexto: Colors.white,
    );

    _desenharCardDivulgacao(
      canvas: canvas,
      paint: paint,
      area: areaWeb,
      titulo: 'Acesse pela Web',
      subtitulo: ' ',
      icone: Icons.language_rounded,
      qrImage: qrWeb,
      tamanhoQr: tamanhoQr,
      margem: margem,
      fundo: Colors.white,
      corTexto: Colors.black,
      corBorda: Colors.black,
    );
  }

  static void _desenharCardDivulgacao({
    required Canvas canvas,
    required Paint paint,
    required Rect area,
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required ui.Image? qrImage,
    required double tamanhoQr,
    required double margem,
    required Color fundo,
    required Color corTexto,
    Color? corBorda,
  }) {
    paint.color = fundo;

    canvas.drawRRect(
      RRect.fromRectAndRadius(area, const Radius.circular(22)),
      paint,
    );

    if (corBorda != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(area, const Radius.circular(24)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = corBorda,
      );
    }

    final areaTitulo = Rect.fromLTWH(
      area.left + 12,
      area.top + 8,
      area.width - 24,
      44,
    );

    _desenharLinhaCentralizadaComIcone(
      canvas,
      area: areaTitulo,
      icone: icone,
      texto: titulo,
      tamanhoIcone: 23,
      tamanhoTexto: 20,
      cor: corTexto,
      peso: FontWeight.w800,
      espacamento: 7,
    );

    if (qrImage != null) {
      final areaBranca = Rect.fromLTWH(
        area.left + ((area.width - (tamanhoQr + margem * 2)) / 2),
        area.top + 45,
        tamanhoQr + margem * 2,
        tamanhoQr + margem * 2,
      );

      canvas.drawRect(
        areaBranca,
        Paint()..color = const ui.Color.fromARGB(255, 231, 201, 65),
      );

      final areaQr = Rect.fromLTWH(
        areaBranca.left + margem,
        areaBranca.top + margem,
        tamanhoQr,
        tamanhoQr,
      );

      canvas.drawImageRect(
        qrImage,
        Rect.fromLTWH(
          0,
          0,
          qrImage.width.toDouble(),
          qrImage.height.toDouble(),
        ),
        areaQr,
        Paint()
          ..isAntiAlias = false
          ..filterQuality = FilterQuality.none,
      );
    }

    _desenharTexto(
      canvas,
      texto: subtitulo,
      posicao: Offset(area.left + 12, area.bottom - 27),
      larguraMaxima: area.width - 24,
      tamanho: 13,
      cor: corTexto,
      peso: FontWeight.w700,
      alinhamento: TextAlign.center,
    );
  }

  static void _desenharRodape({
    required Canvas canvas,
    required String urlWeb,
  }) {
    _desenharTexto(
      canvas,
      texto: 'Presente enviado através do app Clubbar',
      posicao: const Offset(84, 1710),
      larguraMaxima: 912,
      tamanho: 23,
      cor: Colors.black,
      peso: FontWeight.w700,
      alinhamento: TextAlign.center,
    );
  }

  static Future<ui.Image?> _gerarQrImage({
    required String conteudo,
    required double tamanho,
  }) async {
    final valor = conteudo.trim();

    if (valor.isEmpty) return null;

    final painter = QrPainter(
      data: valor,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      gapless: false,
      color: Colors.black,
      emptyColor: Colors.white,
    );

    final byteData = await painter.toImageData(
      tamanho,
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) return null;

    final codec = await ui.instantiateImageCodec(
      byteData.buffer.asUint8List(),
      targetWidth: tamanho.toInt(),
      targetHeight: tamanho.toInt(),
    );

    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static Future<ui.Image?> _carregarImagem(String url) async {
    try {
      final valor = url.trim();
      if (valor.isEmpty) return null;

      final resposta = await http.get(Uri.parse(valor));

      if (resposta.statusCode != 200 || resposta.bodyBytes.isEmpty) {
        debugPrint(
          '[PRESENTE] Falha ao baixar imagem. Status: ${resposta.statusCode}',
        );
        return null;
      }

      final codec = await ui.instantiateImageCodec(resposta.bodyBytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('[PRESENTE] Erro ao carregar imagem: $e');
      return null;
    }
  }

  static void _desenharImagemContain({
    required Canvas canvas,
    required ui.Image imagem,
    required Rect destino,
  }) {
    final larguraImagem = imagem.width.toDouble();
    final alturaImagem = imagem.height.toDouble();

    final escala = math.min(
      destino.width / larguraImagem,
      destino.height / alturaImagem,
    );

    final larguraFinal = larguraImagem * escala;
    final alturaFinal = alturaImagem * escala;

    final x = destino.left + ((destino.width - larguraFinal) / 2);
    final y = destino.top + ((destino.height - alturaFinal) / 2);

    final destinoFinal = Rect.fromLTWH(x, y, larguraFinal, alturaFinal);

    canvas.drawImageRect(
      imagem,
      Rect.fromLTWH(0, 0, larguraImagem, alturaImagem),
      destinoFinal,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  static void _desenharLinhaCentralizadaComIcone(
    Canvas canvas, {
    required Rect area,
    required IconData icone,
    required String texto,
    required double tamanhoIcone,
    required double tamanhoTexto,
    required Color cor,
    required FontWeight peso,
    double espacamento = 12,
  }) {
    final iconePainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icone.codePoint),
        style: TextStyle(
          fontFamily: icone.fontFamily,
          package: icone.fontPackage,
          fontSize: tamanhoIcone,
          color: cor,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textoPainter = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          color: cor,
          fontSize: tamanhoTexto,
          fontWeight: peso,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: area.width - iconePainter.width - espacamento - 24);

    final larguraTotal = iconePainter.width + espacamento + textoPainter.width;

    final alturaTotal = math.max(iconePainter.height, textoPainter.height);

    final xInicial = area.left + ((area.width - larguraTotal) / 2);
    final yInicial = area.top + ((area.height - alturaTotal) / 2);

    iconePainter.paint(
      canvas,
      Offset(xInicial, yInicial + ((alturaTotal - iconePainter.height) / 2)),
    );

    textoPainter.paint(
      canvas,
      Offset(
        xInicial + iconePainter.width + espacamento,
        yInicial + ((alturaTotal - textoPainter.height) / 2),
      ),
    );
  }

  static void _desenharTextoCentralizadoNaArea(
    Canvas canvas, {
    required String texto,
    required Rect area,
    required double tamanho,
    required Color cor,
    required FontWeight peso,
    double espacamentoLetras = 0,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          color: cor,
          fontSize: tamanho,
          fontWeight: peso,
          height: 1,
          letterSpacing: espacamentoLetras,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: area.width);

    final x = area.left + ((area.width - painter.width) / 2);
    final y = area.top + ((area.height - painter.height) / 2);

    painter.paint(canvas, Offset(x, y));
  }

  static void _desenharTexto(
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
}
