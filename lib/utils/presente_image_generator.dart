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
      const altura = 2050.0;

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

      _desenharCabecalho(canvas: canvas, paint: paint, largura: largura);

      const areaCartao = Rect.fromLTWH(50, 190, 980, 2120);

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

      _desenharInstrucaoUso(canvas: canvas, ehIngresso: ehIngresso);

      _desenharDivisor(canvas: canvas, paint: paint, y: 1700);

      _desenharMarketing(canvas: canvas);

      await _desenharAreaDivulgacao(
        canvas: canvas,
        paint: paint,
        urlApp: urlApp,
        urlWeb: urlWeb,
      );

      _desenharRodape(canvas: canvas);

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
    required double largura,
  }) {
    const areaCabecalho = Rect.fromLTWH(0, 0, 1080, 155);

    paint.color = Colors.black;
    canvas.drawRect(areaCabecalho, paint);

    _desenharTextoCentralizadoNaArea(
      canvas,
      texto: 'CLUBBAR',
      area: areaCabecalho,
      tamanho: 58,
      cor: Colors.white,
      peso: FontWeight.w900,
      espacamentoLetras: 2,
    );
  }

  static void _desenharFaixaPresente({
    required Canvas canvas,
    required Paint paint,
  }) {
    const areaFaixa = Rect.fromLTWH(90, 230, 900, 92);

    paint.color = Colors.amber;
    canvas.drawRRect(
      RRect.fromRectAndRadius(areaFaixa, const Radius.circular(24)),
      paint,
    );

    _desenharLinhaCentralizadaComIcone(
      canvas,
      area: areaFaixa,
      icone: Icons.card_giftcard_rounded,
      texto: 'Você recebeu um presente!',
      tamanhoIcone: 43,
      tamanhoTexto: 37,
      cor: Colors.black,
      peso: FontWeight.w900,
      espacamento: 14,
    );
  }

  static Future<void> _desenharImagemPrincipal({
    required Canvas canvas,
    required Paint paint,
    required String imagemUrl,
    required bool ehIngresso,
  }) async {
    const areaFotoRect = Rect.fromLTWH(90, 355, 900, 410);

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
      posicao: const Offset(90, 805),
      larguraMaxima: 900,
      tamanho: 46,
      cor: Colors.black,
      peso: FontWeight.w900,
      maxLines: 2,
      alinhamento: TextAlign.center,
    );

    _desenharTexto(
      canvas,
      texto: nomeLoja,
      posicao: const Offset(90, 925),
      larguraMaxima: 900,
      tamanho: 38,
      cor: Colors.black87,
      peso: FontWeight.w900,
      alinhamento: TextAlign.center,
    );

    if (nomeRemetente.trim().isNotEmpty) {
      _desenharTexto(
        canvas,
        texto: 'Presente de ${nomeRemetente.trim()}',
        posicao: const Offset(90, 980),
        larguraMaxima: 900,
        tamanho: 31,
        cor: Colors.black54,
        peso: FontWeight.w700,
        alinhamento: TextAlign.center,
      );
    }

    if (validade.trim().isNotEmpty) {
      const areaValidade = Rect.fromLTWH(230, 1032, 620, 62);

      final paint = Paint()..color = const Color(0xFFFFF2CC);

      canvas.drawRRect(
        RRect.fromRectAndRadius(areaValidade, const Radius.circular(20)),
        paint,
      );

      _desenharLinhaCentralizadaComIcone(
        canvas,
        area: areaValidade,
        icone: Icons.schedule_rounded,
        texto: 'Válido até ${validade.trim()}',
        tamanhoIcone: 28,
        tamanhoTexto: 27,
        cor: const Color(0xFF8A5A00),
        peso: FontWeight.w800,
        espacamento: 10,
      );
    }
  }

  static Future<void> _desenharQrPrincipal({
    required Canvas canvas,
    required Paint paint,
    required String dadosQr,
  }) async {
    const tamanhoQr = 540.0;
    const margemQr = 38.0;
    const tamanhoAreaQr = tamanhoQr + (margemQr * 2);

    const areaBrancaQr = Rect.fromLTWH(
      (1080 - tamanhoAreaQr) / 2,
      1120,
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
      1120 + margemQr,
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

  static void _desenharInstrucaoUso({
    required Canvas canvas,
    required bool ehIngresso,
  }) {
    _desenharTexto(
      canvas,
      texto: ehIngresso
          ? 'Apresente este QR Code na entrada do evento'
          : 'Apresente este QR Code ao atendente',
      posicao: const Offset(90, 1648),
      larguraMaxima: 900,
      tamanho: 30,
      cor: Colors.red,
      peso: FontWeight.w900,
      alinhamento: TextAlign.center,
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
      posicao: const Offset(90, 1740),
      larguraMaxima: 900,
      tamanho: 37,
      cor: Colors.black,
      peso: FontWeight.w900,
      alinhamento: TextAlign.center,
    );

    _desenharTexto(
      canvas,
      texto:
          'Com o Clubbar você compra ingressos, pede bebidas, recebe cashback e presenteia seus amigos.',
      posicao: const Offset(125, 1795),
      larguraMaxima: 830,
      tamanho: 24,
      cor: Colors.black54,
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
    const tamanhoQr = 205.0;
    const margem = 18.0;

    final qrApp = await _gerarQrImage(
      conteudo: urlApp.trim(),
      tamanho: tamanhoQr,
    );

    final qrWeb = await _gerarQrImage(
      conteudo: urlWeb.trim(),
      tamanho: tamanhoQr,
    );

    const areaApp = Rect.fromLTWH(145, 1910, 325, 295);
    const areaWeb = Rect.fromLTWH(610, 1910, 325, 295);

    _desenharCardDivulgacao(
      canvas: canvas,
      paint: paint,
      area: areaApp,
      titulo: 'Baixe o App',
      subtitulo: 'CLUBBAR',
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
      subtitulo: 'clubbar.com.br',
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
      RRect.fromRectAndRadius(area, const Radius.circular(24)),
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
      area.left + 16,
      area.top + 12,
      area.width - 32,
      50,
    );

    _desenharLinhaCentralizadaComIcone(
      canvas,
      area: areaTitulo,
      icone: icone,
      texto: titulo,
      tamanhoIcone: 25,
      tamanhoTexto: 21,
      cor: corTexto,
      peso: FontWeight.w800,
      espacamento: 8,
    );

    if (qrImage != null) {
      final areaBranca = Rect.fromLTWH(
        area.left + ((area.width - (tamanhoQr + margem * 2)) / 2),
        area.top + 62,
        tamanhoQr + margem * 2,
        tamanhoQr + margem * 2,
      );

      canvas.drawRect(areaBranca, Paint()..color = Colors.white);

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
      posicao: Offset(area.left + 10, area.bottom - 35),
      larguraMaxima: area.width - 20,
      tamanho: 18,
      cor: corTexto,
      peso: FontWeight.w700,
      alinhamento: TextAlign.center,
    );
  }

  static void _desenharRodape({required Canvas canvas}) {
    _desenharTexto(
      canvas,
      texto: 'Presente enviado através do Clubbar',
      posicao: const Offset(90, 2250),
      larguraMaxima: 900,
      tamanho: 23,
      cor: Colors.black54,
      peso: FontWeight.w700,
      alinhamento: TextAlign.center,
    );

    _desenharTexto(
      canvas,
      texto: 'www.clubbar.com.br',
      posicao: const Offset(90, 2290),
      larguraMaxima: 900,
      tamanho: 25,
      cor: Colors.black,
      peso: FontWeight.w900,
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
