import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/carteira_badge_notifier.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_page_header.dart';
import '../../utils/date_formatters.dart';

import 'package:share_plus/share_plus.dart';

import '../../utils/presente_image_generator.dart';
import '../../utils/share_image_file.dart';

import 'package:clubbar_cliente/config/app_config.dart';

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
  bool _atualizando = false;

  static final String baseUrl = AppConfig.apiBaseUrl;

  @override
  void initState() {
    super.initState();
    itensTela = List<Map<String, dynamic>>.from(widget.itens);
  }

  bool _isIngresso(Map<String, dynamic> item) {
    return (item['idtipoproduto'] ?? '').toString().toUpperCase() == 'I';
  }

  bool _isDelivery(Map<String, dynamic> item) {
    return (item['tipo_operacao'] ?? '').toString().toUpperCase() == 'DELIVERY';
  }

  bool _ehCortesia(Map<String, dynamic> item) =>
      double.tryParse(
        (item['vrunititvenda'] ?? '').toString().trim().replaceAll(',', '.'),
      ) ==
      0;

  DateTime? _dataValidade(Map<String, dynamic> item) {
    final formatada = (item['dtexpiraitvenda_fmt'] ?? '').toString().trim();
    final partes = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(formatada);
    if (partes != null) {
      return DateTime(
        int.parse(partes[3]!),
        int.parse(partes[2]!),
        int.parse(partes[1]!),
      );
    }
    return DateTime.tryParse((item['dtexpiraitvenda'] ?? '').toString());
  }

  List<List<Map<String, dynamic>>> _agruparProdutos() {
    final grupos = <List<Map<String, dynamic>>>[];
    final indices = <String, int>{};
    for (final item in itensTela) {
      final id = (item['produto_id'] ?? '').toString().trim();
      if (_isDelivery(item) || id.isEmpty || id == '0') {
        grupos.add([item]);
        continue;
      }
      final chave = id;
      final indice = indices[chave];
      if (indice == null) {
        indices[chave] = grupos.length;
        grupos.add([item]);
      } else {
        grupos[indice].add(item);
      }
    }
    for (final grupo in grupos) {
      grupo.sort((a, b) {
        final primeira = _dataValidade(a);
        final segunda = _dataValidade(b);
        if (primeira == null) return segunda == null ? 0 : 1;
        if (segunda == null) return -1;
        return primeira.compareTo(segunda);
      });
    }
    return grupos;
  }

  Future<void> _escolherUnidade(
    List<Map<String, dynamic>> itens, {
    required bool presentear,
  }) async {
    Map<String, dynamic>? selecionado;
    if (itens.length == 1) {
      selecionado = itens.first;
    } else {
      selecionado = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            presentear
                ? 'Escolha uma unidade para presentear'
                : 'Escolha uma unidade',
          ),
          content: SizedBox(
            width: 380,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: itens.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = itens[index];
                final validade = (item['dtexpiraitvenda_fmt'] ?? '')
                    .toString()
                    .trim();
                final quantidade =
                    int.tryParse('${item['qtitvenda'] ?? 1}') ?? 1;
                return ListTile(
                  title: Text(
                    quantidade > 1
                        ? 'Item ${index + 1} • $quantidade unidades'
                        : 'Unidade ${index + 1}',
                  ),
                  subtitle: Text(
                    '${validade.isEmpty ? 'Validade não informada' : 'Válido até $validade'}${_ehCortesia(item) ? ' • Cortesia' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(dialogContext, item),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
    }
    if (!mounted || selecionado == null) return;
    if (presentear) {
      await _confirmarCompartilhamento(selecionado);
    } else {
      await _abrirQrOuRetirada(context, selecionado);
    }
  }

  String _statusEntrega(Map<String, dynamic> item) {
    switch ((item['situacaoentrega'] ?? '').toString().toUpperCase()) {
      case 'AGUARDANDO_ACEITE':
        return 'Aguardando aceite';
      case 'ACEITO':
        return 'Pedido aceito';
      case 'EM_ROTA':
        return 'Saiu para entrega';
      case 'ENTREGUE':
        return 'Entregue';
      case 'RECUSADO':
        return 'Pedido recusado';
      case 'CANCELADO':
        return 'Cancelado';
      default:
        return 'Pedido de entrega';
    }
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
    final token =
        ((_isDelivery(item) ? item['qrcodeentrega'] : item['qrtokenitvenda']) ??
                '')
            .toString()
            .trim();

    if (token.isEmpty) {
      debugPrint(
        '[CARTEIRA] Token QR vazio para itvenda_id=${item['itvenda_id']}',
      );

      return '';
    }

    return 'CLUBBAR-PRODUTO:$token';
  }

  Future<void> _atualizarItens() async {
    if (_atualizando || widget.onAtualizar == null) return;

    setState(() => _atualizando = true);
    try {
      final novosItens = await widget.onAtualizar!();
      CarteiraBadgeNotifier.atualizar();
      if (!mounted) return;
      setState(() => itensTela = novosItens);
    } catch (_) {
      if (mounted) {
        AppSnackBar.erro(context, 'Não foi possível atualizar a carteira.');
      }
    } finally {
      if (mounted) setState(() => _atualizando = false);
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

      urlApp: AppConfig.appWebUrl,
      urlWeb: AppConfig.appWebUrl,
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
        '${AppConfig.appWebUrl}\n\n'
        '$nomeProduto\n'
        '📍 ${widget.nomeLoja}\n\n'
        'Apresente o QR Code ao atendente.';

    try {
      await Share.shareXFiles(
        [
          await ShareImageFile.prepare(
            imagem,
            fileName: 'presente_clubbar_$itvendaId.png',
          ),
        ],
        text: texto,
        subject: 'Presente Clubbar',
      );
    } catch (_) {
      await _copiarMensagemDoPresente(texto);
    }
  }

  Future<void> _copiarMensagemDoPresente(String texto) async {
    try {
      await Clipboard.setData(ClipboardData(text: texto));
      if (!mounted) return;
      AppSnackBar.sucesso(
        context,
        'A mensagem do presente foi copiada. Cole-a no WhatsApp, e-mail ou onde preferir.',
      );
    } catch (_) {
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
        'O QR Code deste pedido ainda não está disponível.',
      );
      return;
    }
    if (_isDelivery(item) &&
        (item['situacaoentrega'] ?? '').toString().toUpperCase() != 'EM_ROTA') {
      AppSnackBar.info(
        context,
        'O QR Code será liberado quando o pedido sair para entrega.',
      );
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.amber, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                width: double.infinity,
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _isDelivery(item)
                            ? 'Pedido para entrega'
                            : (item['nmproduto'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: QrImageView(
                        key: ValueKey(qrData),
                        data: qrData,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Voltar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

        if (!context.mounted) return;

        setState(() {
          itensTela = novosItens;
        });
      } catch (e) {
        if (!context.mounted) return;

        AppSnackBar.erro(
          context,
          'Não foi possível atualizar sua carteira. Puxe a tela para baixo e tente novamente.',
        );
      }
    }
  }

  Widget _textoValidade(
    String validade,
    DateTime? data, {
    bool maisProxima = false,
  }) {
    final hoje = DateUtils.dateOnly(
      DateTime.now().toUtc().subtract(const Duration(hours: 3)),
    );
    final proxima =
        data != null && DateUtils.dateOnly(data).difference(hoje).inDays <= 7;
    return Text(
      maisProxima ? 'Próxima validade: $validade' : 'Válido até $validade',
      style: TextStyle(
        color: proxima ? const Color(0xFFC62828) : Colors.grey.shade700,
        fontSize: 11,
      ),
    );
  }

  Widget _chipStatusEntrega(Map<String, dynamic> item) {
    final emRota =
        (item['situacaoentrega'] ?? '').toString().toUpperCase() == 'EM_ROTA';
    final dataDespacho = (item['dtdespachoentrega'] ?? '').toString().trim();
    final texto = emRota && dataDespacho.isNotEmpty
        ? 'Saiu para entrega em ${DateFormatters.dataHoraSimples(dataDespacho)}'
        : _statusEntrega(item);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emRota ? const Color(0xFFE1F5E8) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: emRota ? const Color(0xFF18763B) : null,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _itemCard(BuildContext context, List<Map<String, dynamic>> itens) {
    final item = itens.first;
    final obs = (item['dsobsitvenda'] ?? '').toString();
    final validade = (item['dtexpiraitvenda_fmt'] ?? '').toString();
    final entrega = _isDelivery(item);
    final quantidade = itens.fold<int>(
      0,
      (total, unidade) =>
          total + (int.tryParse('${unidade['qtitvenda'] ?? 1}') ?? 1),
    );
    final cortesias = itens
        .where(_ehCortesia)
        .fold<int>(
          0,
          (total, unidade) =>
              total + (int.tryParse('${unidade['qtitvenda'] ?? 1}') ?? 1),
        );
    final corProduto = cortesias == quantidade
        ? Colors.green.shade700
        : Colors.blue.shade700;
    final situacaoEntrega = (item['situacaoentrega'] ?? '')
        .toString()
        .toUpperCase();
    final emRota = situacaoEntrega == 'EM_ROTA';
    final pedidoAceito = situacaoEntrega == 'ACEITO';
    final dataAceite = (item['dtaceiteentrega'] ?? '').toString().trim();
    final botaoAceite = pedidoAceito
        ? 'Aceito em ${DateFormatters.dataHoraSimples(dataAceite)}'
        : '';

    return Container(
      margin: EdgeInsets.only(bottom: entrega ? 14 : 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: corProduto, width: 1.5),
        ),
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => entrega
              ? _abrirQrOuRetirada(context, item)
              : _escolherUnidade(itens, presentear: false),
          child: Padding(
            padding: EdgeInsets.all(entrega ? 16 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _imagemItem(item, tamanho: entrega ? 58 : 48),

                    const SizedBox(width: 10),

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

                          const SizedBox(height: 3),

                          if (!entrega)
                            Text(
                              quantidade == 1
                                  ? '1 unidade disponível'
                                  : '$quantidade unidades disponíveis',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (!entrega && cortesias > 0)
                            Text(
                              cortesias == quantidade
                                  ? 'Cortesia'
                                  : '$cortesias ${cortesias == 1 ? 'cortesia' : 'cortesias'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                              ),
                            ),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (validade.isNotEmpty)
                                _textoValidade(
                                  validade,
                                  _dataValidade(item),
                                  maisProxima: itens.length > 1,
                                ),
                              if (entrega) _chipStatusEntrega(item),
                            ],
                          ),

                          if (entrega && obs.trim().isNotEmpty) ...[
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

                SizedBox(height: entrega ? 16 : 5),

                if (!entrega)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 330),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: TextButton.icon(
                                onPressed: () =>
                                    _escolherUnidade(itens, presentear: true),
                                icon: const Icon(
                                  Icons.card_giftcard_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Presentear',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: corProduto,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _escolherUnidade(itens, presentear: false),
                                icon: const Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Exibir QR Code',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: pedidoAceito ? 58 : 46,
                    child: ElevatedButton(
                      onPressed: !emRota
                          ? null
                          : () => _abrirQrOuRetirada(context, item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: emRota
                            ? Colors.amber
                            : pedidoAceito
                            ? const Color(0xFFE1F5E8)
                            : Colors.grey.shade300,
                        disabledBackgroundColor: pedidoAceito
                            ? const Color(0xFFE1F5E8)
                            : Colors.grey.shade300,
                        foregroundColor: emRota
                            ? Colors.black
                            : pedidoAceito
                            ? const Color(0xFF18763B)
                            : Colors.grey.shade500,
                        disabledForegroundColor: pedidoAceito
                            ? const Color(0xFF18763B)
                            : Colors.grey.shade500,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            pedidoAceito
                                ? Icons.storefront_rounded
                                : Icons.qr_code_2_rounded,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: pedidoAceito
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Pedido aceito',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (dataAceite.isNotEmpty)
                                        Text(
                                          botaoAceite,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                    ],
                                  )
                                : Text(
                                    emRota
                                        ? 'Exibir QR Code de entrega'
                                        : _statusEntrega(item),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (entrega) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          (item['situacaovenda'] ?? '')
                                      .toString()
                                      .toUpperCase() ==
                                  'PAGA'
                              ? 'Pagamento realizado. Apresente o QR Code ao motoboy.'
                              : 'Apresente o QR Code ao motoboy na entrega.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagemItem(Map<String, dynamic> item, {double tamanho = 58}) {
    final url = _buildImageUrl((item['urlfotoproduto'] ?? '').toString());

    if (url.isEmpty) {
      return _placeholderItem(item, tamanho: tamanho);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        url,
        width: tamanho,
        height: tamanho,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholderItem(item, tamanho: tamanho),
      ),
    );
  }

  Widget _placeholderItem(Map<String, dynamic> item, {double tamanho = 58}) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
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

      appBar: ClubbarAppBar(
        titulo: 'Minha Carteira - Produtos',
        iconeTitulo: Icons.account_balance_wallet_rounded,
        corIconeTitulo: Colors.amber,
        mostrarVoltar: true,
        mostrarSessao: false,
        onVoltar: widget.onVoltar,
        actions: [
          IconButton(
            tooltip: 'Atualizar carteira',
            onPressed: _atualizando ? null : _atualizarItens,
            icon: _atualizando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),

      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: widget.nomeLoja,
            subtitulo: totalUnidades == 1
                ? '1 item disponível'
                : '$totalUnidades itens disponíveis',
            icone: Icons.inventory_2_rounded,
            imagemAvatarUrl: _buildImageUrl(widget.logoLoja),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _atualizarItens,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  if (itensTela.any((item) => !_isDelivery(item))) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Apresente o QR Code para o atendente',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (itensTela.isEmpty)
                    _estadoVazio()
                  else
                    ..._agruparProdutos().map(
                      (itens) => _itemCard(context, itens),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
