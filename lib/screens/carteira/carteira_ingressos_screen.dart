import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/carteira_badge_notifier.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../services/api_service.dart';
import '../../utils/cpf_utils.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_page_header.dart';
import '../../utils/value_formatters.dart';
import '../../utils/presente_image_generator.dart';
import 'package:clubbar_cliente/config/app_config.dart';

class CarteiraIngressosScreen extends StatefulWidget {
  final String nomeLoja;
  final String logoLoja;
  final String nomeCliente;
  final List<Map<String, dynamic>> itens;
  final Future<List<Map<String, dynamic>>> Function()? onAtualizar;
  final VoidCallback onVoltar;

  const CarteiraIngressosScreen({
    super.key,
    required this.nomeLoja,
    required this.logoLoja,
    required this.nomeCliente,
    required this.itens,
    required this.onAtualizar,
    required this.onVoltar,
  });

  @override
  State<CarteiraIngressosScreen> createState() =>
      _CarteiraIngressosScreenState();
}

class _CarteiraIngressosScreenState extends State<CarteiraIngressosScreen> {
  late List<Map<String, dynamic>> itensTela;
  final ApiService apiService = ApiService();

  static final String baseUrl = AppConfig.apiBaseUrl;

  @override
  void initState() {
    super.initState();
    itensTela = _somenteIngressosFuturos(widget.itens);
  }

  List<Map<String, dynamic>> _somenteIngressosFuturos(
    List<Map<String, dynamic>> itens,
  ) {
    final hoje = DateTime.now();
    final inicioHoje = DateTime(hoje.year, hoje.month, hoje.day);
    return itens
        .where((item) {
          final data = DateTime.tryParse(
            (item['dtinicioevento'] ?? '').toString(),
          );
          if (data == null) return true;
          final diaEvento = DateTime(data.year, data.month, data.day);
          return !diaEvento.isBefore(inicioHoje);
        })
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  DateTime? _dataEvento(Map<String, dynamic> item) =>
      DateTime.tryParse((item['dtinicioevento'] ?? '').toString());

  DateTime? _dataCompra(Map<String, dynamic> item) =>
      DateTime.tryParse((item['dtcriacao'] ?? '').toString());

  Future<void> _compartilharIngresso(Map<String, dynamic> item) async {
    final token = (item['qrtokenitvenda'] ?? '').toString().trim();
    final itvendaId = int.tryParse('${item['itvenda_id'] ?? 0}') ?? 0;
    if (token.isEmpty || itvendaId == 0) {
      AppSnackBar.erro(context, 'QR Code do ingresso não disponível.');
      return;
    }
    AppSnackBar.info(context, 'Preparando o ingresso...');
    final nomeEvento =
        (item['nmevento'] ?? item['nmproduto'] ?? 'Ingresso Clubbar')
            .toString();
    final dataEvento = (item['dtinicioevento_fmt'] ?? '').toString();
    final imagem = await PresenteImageGenerator.gerar(
      tipo: 'I',
      nomeItem: nomeEvento,
      nomeLoja: widget.nomeLoja,
      nomeRemetente: widget.nomeCliente,
      imagemUrl: _buildImageUrl((item['urlfotoproduto'] ?? '').toString()),
      dadosQr: 'CLUBBAR-INGRESSO:$token',
      validade: dataEvento,
    );
    if (!mounted) return;
    if (imagem == null) {
      AppSnackBar.erro(context, 'Não foi possível gerar o ingresso.');
      return;
    }
    final texto =
        'Você recebeu um ingresso pelo Clubbar!\n\n'
        '$nomeEvento\n'
        'Data e hora: $dataEvento\n'
        'Recebido de: ${widget.nomeCliente}\n\n'
        'Apresente o QR Code na entrada junto com seu documento de identificação.';
    try {
      await Share.shareXFiles(
        [
          XFile.fromData(
            imagem,
            name: 'ingresso_clubbar_$itvendaId.png',
            mimeType: 'image/png',
          ),
        ],
        text: texto,
        subject: 'Ingresso Clubbar',
      );
    } catch (_) {
      if (mounted) {
        AppSnackBar.erro(context, 'Não foi possível compartilhar o ingresso.');
      }
    }
  }

  Future<void> _cancelarIngresso(Map<String, dynamic> item) async {
    final dataEvento = _dataEvento(item);
    final dataCompra = _dataCompra(item);
    if (dataEvento == null || dataCompra == null) {
      AppSnackBar.erro(context, 'Data da compra ou do evento não informada.');
      return;
    }
    final agora = DateTime.now();
    final dentroDosSeteDias = !agora.isAfter(
      dataCompra.add(const Duration(days: 7)),
    );
    final antesDasQuarentaEOitoHoras = !agora.isAfter(
      dataEvento.subtract(const Duration(hours: 48)),
    );
    if (!dentroDosSeteDias || !antesDasQuarentaEOitoHoras) {
      AppSnackBar.erro(
        context,
        'Cancelamento não permitido. O ingresso só pode ser cancelado em até '
        '7 dias após a compra e com no mínimo 48 horas de antecedência do '
        'início do evento.',
      );
      return;
    }
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar ingresso'),
        content: const Text(
          'Deseja cancelar somente este ingresso? O valor correspondente a '
          'este item será solicitado como reembolso pelo mesmo meio de '
          'pagamento. Os demais ingressos continuarão disponíveis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Não'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancelar ingresso'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      final itvendaId = int.parse('${item['itvenda_id']}');
      await apiService.cancelarIngresso(itvendaId: itvendaId);
      if (!mounted) return;
      setState(() {
        itensTela.removeWhere(
          (registro) => registro['itvenda_id'] == item['itvenda_id'],
        );
      });
      CarteiraBadgeNotifier.atualizar();
      AppSnackBar.sucesso(
        context,
        'Ingresso cancelado. O reembolso deste item foi solicitado com sucesso.',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _formatarCpf(String cpf) {
    final numeros = cpf.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length != 11) return cpf;

    return '${numeros.substring(0, 3)}.'
        '${numeros.substring(3, 6)}.'
        '${numeros.substring(6, 9)}-'
        '${numeros.substring(9, 11)}';
  }

  String _buildImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }

  Future<void> _abrirDialogAlterarParticipante(
    Map<String, dynamic> item,
  ) async {
    final nomeController = TextEditingController(
      text: (item['nmparticipante'] ?? '').toString(),
    );

    final cpfController = TextEditingController(
      text: _formatarCpf((item['cpfparticipante'] ?? '').toString()),
    );

    final resultado = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text('Alterar participante'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome do participante',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cpfController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'CPF do participante',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final nome = nomeController.text.trim();
                final cpf = cpfController.text.replaceAll(
                  RegExp(r'[^0-9]'),
                  '',
                );

                if (nome.isEmpty || cpf.isEmpty) {
                  AppSnackBar.erro(
                    context,
                    'Informe nome e CPF do participante.',
                  );
                  return;
                }

                if (!CpfUtils.validar(cpf)) {
                  AppSnackBar.erro(context, 'CPF do cliente inválido.');
                  return;
                }

                Navigator.pop(context, {'nome': nome, 'cpf': cpf});
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    nomeController.dispose();
    cpfController.dispose();

    if (resultado == null) return;

    try {
      final itvendaId = int.tryParse('${item['itvenda_id'] ?? 0}') ?? 0;

      if (itvendaId == 0) {
        throw Exception('Item da venda inválido');
      }

      await apiService.alterarParticipanteItVenda(
        itvendaId: itvendaId,
        nmparticipante: resultado['nome']!,
        cpfparticipante: resultado['cpf']!,
      );

      if (!mounted) return;

      setState(() {
        item['nmparticipante'] = resultado['nome'];
        item['cpfparticipante'] = resultado['cpf'];
      });

      AppSnackBar.sucesso(context, 'Participante alterado com sucesso.');
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, 'Erro ao alterar participante.');
    }
  }

  Future<void> _abrirQrOuRetirada(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final token = (item['qrtokenitvenda'] ?? '').toString().trim();
    final qrData = 'CLUBBAR-INGRESSO:$token';

    if (token.isEmpty) {
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
                  'Validação do ingresso',
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
                if ((item['nmparticipante'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          (item['nmparticipante'] ?? '').toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          _formatarCpf(
                            item['cpfparticipante'] ?? '',
                          ).toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Apresente este QR Code na portaria.',
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
        itensTela = _somenteIngressosFuturos(novosItens);
      });
    }
  }

  Widget _itemCard(BuildContext context, Map<String, dynamic> item) {
    final nomeIngresso = (item['nmevento'] ?? item['nmproduto'] ?? 'Ingresso')
        .toString()
        .trim();

    final nomeParticipante = (item['nmparticipante'] ?? '').toString().trim();

    final cpfOriginal = (item['cpfparticipante'] ?? '').toString().trim();

    final cpfParticipante = cpfOriginal.isEmpty
        ? ''
        : _formatarCpf(cpfOriginal);

    final dataCompra = (item['dtcriacao_fmt'] ?? '').toString().trim();
    final dataEvento = (item['dtinicioevento_fmt'] ?? '').toString().trim();

    final valor = double.tryParse('${item['vrunititvenda'] ?? 0}') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Faixa superior do ingresso
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.blue.withOpacity(0.12),
                    Colors.amber.withOpacity(0.10),
                  ],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: Colors.blue.withOpacity(0.20)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _imagemItem(item),
                    ),
                  ),

                  const SizedBox(width: 4),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nomeIngresso,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          dataEvento.isEmpty
                              ? 'Data do evento não informada'
                              : dataEvento,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(15, 4, 5, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Valor e data da compra
                  Row(
                    children: [
                      _informacaoIngresso(
                        icone: Icons.payments_outlined,
                        titulo: 'Valor',
                        valor: ValueFormatters.moeda(valor),
                        corIcone: Colors.green.shade700,
                      ),

                      const SizedBox(width: 5),

                      _informacaoIngresso(
                        icone: Icons.shopping_bag_outlined,
                        titulo: 'Data e hora da compra',
                        valor: dataCompra.isEmpty
                            ? 'Não informada'
                            : dataCompra,
                        corIcone: Colors.blue.shade700,
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Participante
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.withOpacity(0.16)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.blue,
                            size: 22,
                          ),
                        ),

                        const SizedBox(width: 2),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Participante',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),

                              const SizedBox(height: 3),

                              Text(
                                nomeParticipante.isEmpty
                                    ? 'Participante não informado'
                                    : nomeParticipante,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),

                              if (cpfParticipante.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'CPF: $cpfParticipante',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        IconButton(
                          tooltip: 'Alterar participante',
                          onPressed: () =>
                              _abrirDialogAlterarParticipante(item),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.amber.withOpacity(0.18),
                            foregroundColor: Colors.black87,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 19),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Botão principal
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () => _abrirQrOuRetirada(context, item),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 22),
                      label: const Text(
                        'Exibir ingresso e QR Code',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _compartilharIngresso(item),
                          icon: const Icon(Icons.ios_share_rounded),
                          label: const Text('Compartilhar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                            side: BorderSide(color: Colors.blue.shade200),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelarIngresso(item),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancelar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade200),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Apresente o QR Code na portaria do evento.',
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagemItem(Map<String, dynamic> item) {
    final url = _buildImageUrl((item['urlfotoproduto'] ?? '').toString());

    if (url.isEmpty) {
      return _placeholderItem(item);
    }

    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _placeholderItem(item),
    );
  }

  Widget _placeholderItem(Map<String, dynamic> item) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.amber.withOpacity(0.14),
      alignment: Alignment.center,
      child: Icon(
        Icons.confirmation_number_outlined,
        color: Colors.amber.shade800,
        size: 28,
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
            Icons.confirmation_number_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          const Text(
            'Nenhum ingresso disponível',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Não há ingressos disponíveis para uso neste estabelecimento.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _informacaoIngresso({
    required IconData icone,
    required String titulo,
    required String valor,
    Color? corIcone,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icone, size: 18, color: corIcone ?? Colors.grey.shade700),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalUnidades = itensTela.fold<int>(0, (total, item) {
      final quantidade = int.tryParse('${item['qtitvenda'] ?? 0}') ?? 0;

      return total + quantidade;
    });

    final subtituloAux = totalUnidades == 1
        ? '1 ingresso disponível'
        : '$totalUnidades ingressos disponíveis';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: ClubbarAppBar(mostrarVoltar: true, onVoltar: widget.onVoltar),

      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: widget.nomeLoja,
            subtitulo: subtituloAux,
            icone: Icons.storefront_rounded,
            imagemAvatarUrl: _buildImageUrl(widget.logoLoja),
            tamanhoAvatar: 58,
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (widget.onAtualizar == null) return;

                final novosItens = await widget.onAtualizar!();

                CarteiraBadgeNotifier.atualizar();

                if (!mounted) return;

                setState(() {
                  itensTela = _somenteIngressosFuturos(novosItens);
                });
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
