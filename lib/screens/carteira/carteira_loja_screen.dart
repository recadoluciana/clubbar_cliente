import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/carteira_badge_notifier.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_page_header.dart';
import '../../utils/value_formatters.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/presente_image_generator.dart';

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

  static const String baseUrl = 'https://api.clubbar.com.br';

  @override
  void initState() {
    super.initState();
    itensTela = List<Map<String, dynamic>>.from(widget.itens);
  }

  bool _isIngresso(Map<String, dynamic> item) {
    return (item['idtipoproduto'] ?? '').toString().toUpperCase() == 'I';
  }

  String _buildImageUrl(String path) {
    final caminho = path.trim();

    if (caminho.isEmpty) {
      return '';
    }

    if (caminho.startsWith('http://') || caminho.startsWith('https://')) {
      return caminho;
    }

    final url = caminho.startsWith('/')
        ? '$baseUrl$caminho'
        : '$baseUrl/$caminho';

    //debugPrint('[CARTEIRA] Caminho recebido: $caminho');
    //debugPrint('[CARTEIRA] URL final da imagem: $url');

    return url;
  }

  String _montarDadosQr(Map<String, dynamic> item) {
    final token = (item['qrtokenitvenda'] ?? '').toString().trim();

    if (token.isEmpty) {
      debugPrint(
        '[PRESENTEAR] qrtokenitvenda vazio para itvenda_id=${item['itvenda_id']}',
      );

      return '';
    }

    return 'CLUBBAR-PRODUTO:$token';
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

    final imagemUrl = _buildImageUrl((item['urlfotoproduto'] ?? '').toString());

    final imagem = await PresenteImageGenerator.gerar(
      tipo: 'P',
      nomeItem: (item['nmproduto'] ?? '').toString(),
      nomeLoja: widget.nomeLoja,
      nomeRemetente: widget.nomeCliente,
      imagemUrl: imagemUrl,
      dadosQr: _montarDadosQr(item),
      // Validade do item da venda
      validade: (item['dtexpiraitvenda_fmt'] ?? '').toString().trim(),

      urlApp: 'https://clubbar.com.br/app',
      urlWeb: 'https://app.clubbar.com.br',
    );

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
        '🎁 Você ganhou um presente através do app Clubbar!\n'
        'app.clubbar.com.br\n\n'
        '$nomeProduto\n'
        '📍 ${widget.nomeLoja}\n\n'
        'Apresente o QR Code ao atendente.';

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
    final qrData = _montarDadosQr(item);

    if (qrData.isEmpty) {
      AppSnackBar.erro(
        context,
        'Este produto ainda não está pronto para retirada. Atualize sua carteira e tente novamente.',
      );
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
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
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
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

    // Atualiza os itens depois que o QR for fechado.
    // Se o barman já deu baixa, o produto deixa de aparecer.
    if (widget.onAtualizar != null) {
      try {
        final novosItens = await widget.onAtualizar!();

        CarteiraBadgeNotifier.atualizar();

        if (!mounted) return;

        setState(() {
          itensTela = novosItens;
        });
      } catch (e) {
        if (!mounted) return;

        AppSnackBar.erro(
          context,
          'Não foi possível atualizar sua carteira. Puxe a tela para baixo e tente novamente.',
        );
      }
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
