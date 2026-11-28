import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/carteira_badge_notifier.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../services/api_service.dart';
import '../../utils/cpf_utils.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_page_header.dart';
import '../../utils/presente_image_generator.dart';
import '../../utils/share_image_file.dart';

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

class _DivisoriaIngressoPainter extends CustomPainter {
  const _DivisoriaIngressoPainter(this.cor);

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final linha = Paint()
      ..color = cor.withValues(alpha: .35)
      ..strokeWidth = 1;
    for (double x = 15; x < size.width - 15; x += 9) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + 4, size.height / 2),
        linha,
      );
    }
    final recorte = Paint()..color = const Color(0xFFF6F6F6);
    canvas.drawCircle(Offset(0, size.height / 2), 7, recorte);
    canvas.drawCircle(Offset(size.width, size.height / 2), 7, recorte);
  }

  @override
  bool shouldRepaint(covariant _DivisoriaIngressoPainter antigo) =>
      antigo.cor != cor;
}

class _CarteiraIngressosScreenState extends State<CarteiraIngressosScreen> {
  late final ValueNotifier<List<Map<String, dynamic>>> _itens;
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _eventoAberto = false;
  List<Map<String, dynamic>> get itensTela => _itens.value;
  final ApiService apiService = ApiService();

  static final String baseUrl = AppConfig.apiBaseUrl;

  @override
  void initState() {
    super.initState();
    _itens = ValueNotifier(_ordenarIngressos(widget.itens));
  }

  @override
  void dispose() {
    _itens.dispose();
    super.dispose();
  }

  Future<void> _atualizarIngressos() async {
    if (widget.onAtualizar == null) return;
    try {
      final novosItens = await widget.onAtualizar!();
      if (!mounted) return;
      _itens.value = _ordenarIngressos(novosItens);
      CarteiraBadgeNotifier.atualizar();
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, apiService.mensagemErroAmigavel(e));
      }
    }
  }

  void _voltar() {
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    } else {
      widget.onVoltar();
    }
  }

  Future<void> _abrirEvento(Map<String, dynamic> evento) async {
    if (_eventoAberto) return;
    _eventoAberto = true;
    final chave = _chaveEvento(evento);
    try {
      await _navigatorKey.currentState!.push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'ingressos-evento'),
          builder: (context) => ValueListenableBuilder(
            valueListenable: _itens,
            builder: (context, itens, _) => _telaIngressosEvento(
              context,
              evento,
              itens.where((item) => _chaveEvento(item) == chave).toList(),
            ),
          ),
        ),
      );
    } finally {
      _eventoAberto = false;
    }
  }

  List<Map<String, dynamic>> _ordenarIngressos(
    List<Map<String, dynamic>> itens,
  ) {
    // A API já filtra os ingressos pelo término efetivo do evento. Não
    // repetimos a regra no Client para evitar esconder eventos em andamento.
    final ingressos = itens
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    ingressos.sort((primeiro, segundo) {
      final dataPrimeiro = DateTime.tryParse(
        (primeiro['dtinicioevento'] ?? '').toString(),
      );
      final dataSegundo = DateTime.tryParse(
        (segundo['dtinicioevento'] ?? '').toString(),
      );

      if (dataPrimeiro == null && dataSegundo == null) return 0;
      if (dataPrimeiro == null) return 1;
      if (dataSegundo == null) return -1;
      return dataPrimeiro.compareTo(dataSegundo);
    });

    return ingressos;
  }

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
      nomeParticipante: (item['nmparticipante'] ?? '').toString(),
      cpfParticipante: _formatarCpf((item['cpfparticipante'] ?? '').toString()),
      urlApp: AppConfig.appWebUrl,
      urlWeb: AppConfig.appWebUrl,
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
      final caixa = context.findRenderObject() as RenderBox?;
      final origem = caixa != null && caixa.hasSize
          ? caixa.localToGlobal(Offset.zero) & caixa.size
          : null;
      await Share.shareXFiles(
        [
          await ShareImageFile.prepare(
            imagem,
            fileName: 'ingresso_clubbar_$itvendaId.png',
          ),
        ],
        // Alguns aplicativos no iOS não recebem corretamente imagem e texto
        // juntos. O ingresso já contém todos os dados na própria imagem.
        text: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
            ? null
            : texto,
        subject: 'Ingresso Clubbar',
        sharePositionOrigin: origem,
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.erro(
        context,
        'Não foi possível compartilhar a imagem do ingresso com o QR Code. Tente novamente.',
      );
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
    final itvendaId = int.tryParse('${item['itvenda_id'] ?? 0}') ?? 0;
    if (itvendaId == 0) {
      AppSnackBar.erro(context, 'Item da venda inválido');
      return;
    }

    try {
      await apiService.validarAlteracaoParticipanteItVenda(
        itvendaId: itvendaId,
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }

    if (!mounted) return;

    final nomeController = TextEditingController();
    final cpfController = TextEditingController();

    final tipoPreco = (item['tipopreco'] ?? '').toString().toUpperCase();
    final ehMeiaEntrada = tipoPreco.startsWith('MEIA');
    bool confirmouMeiaEntrada = false;

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Transferir ingresso'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'A transferência é gratuita e ficará registrada no histórico do ingresso.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nomeController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome do novo participante',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cpfController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'CPF do novo participante',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (ehMeiaEntrada) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Este ingresso é de meia-entrada. O novo participante precisa ter direito à meia-entrada e apresentar o comprovante na entrada.',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: confirmouMeiaEntrada,
                      onChanged: (valor) => setDialogState(
                        () => confirmouMeiaEntrada = valor ?? false,
                      ),
                      title: const Text(
                        'Confirmo que o novo participante tem direito à meia-entrada.',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
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
                      dialogContext,
                      'Informe nome e CPF do novo participante.',
                    );
                    return;
                  }

                  if (!CpfUtils.validar(cpf)) {
                    AppSnackBar.erro(
                      dialogContext,
                      'CPF do participante inválido.',
                    );
                    return;
                  }
                  if (ehMeiaEntrada && !confirmouMeiaEntrada) {
                    AppSnackBar.erro(
                      dialogContext,
                      'Confirme o direito à meia-entrada do novo participante.',
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, {
                    'nome': nome,
                    'cpf': cpf,
                    'confirmar_meia_entrada': confirmouMeiaEntrada,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Transferir'),
              ),
            ],
          ),
        );
      },
    );

    nomeController.dispose();
    cpfController.dispose();

    if (resultado == null) return;

    try {
      await apiService.alterarParticipanteItVenda(
        itvendaId: itvendaId,
        nmparticipante: resultado['nome']!,
        cpfparticipante: resultado['cpf']!,
        confirmarMeiaEntrada: resultado['confirmar_meia_entrada'] == true,
      );

      if (!mounted) return;

      final historico = (item['historico_participantes'] as List? ?? [])
          .whereType<Map>()
          .map((registro) => Map<String, dynamic>.from(registro))
          .toList();
      historico.add({
        'nmparticipanteanterior': item['nmparticipante'],
        'cpfparticipanteanterior': item['cpfparticipante'],
        'nmparticipantenovo': resultado['nome'],
        'cpfparticipantenovo': resultado['cpf'],
      });
      item['historico_participantes'] = historico;
      item['nmparticipante'] = resultado['nome'];
      item['cpfparticipante'] = resultado['cpf'];
      _itens.value = List.of(itensTela);

      AppSnackBar.sucesso(context, 'Ingresso transferido com sucesso.');
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _abrirQrOuRetirada(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final token = (item['qrtokenitvenda'] ?? '').toString().trim();
    final qrData = 'CLUBBAR-INGRESSO:$token';
    final corIngresso = _corIngresso(item);
    final nomeEvento = _primeiroTexto(item, const [
      'nmevento',
      'nmproduto',
    ], padrao: 'Ingresso Clubbar');
    final setor = _primeiroTexto(item, const [
      'nmsetor',
      'nmsetoringresso',
      'setor',
    ], padrao: 'Não informado');
    final preco = _primeiroTexto(item, const [
      'nmpreco',
      'nmprecoingresso',
      'tipopreco',
    ]);
    final modalidade = preco.isNotEmpty
        ? preco
        : _primeiroTexto(item, const [
            'tipo_ingresso',
          ], padrao: 'Não informada');
    final beneficio = _primeiroTexto(item, const [
      'nmbeneficiosnapshot',
      'nmbeneficio',
      'beneficio',
    ]);
    final nomeParticipante = _primeiroTexto(item, const [
      'nmparticipante',
    ], padrao: 'Não informado');
    final cpfParticipante = _formatarCpf(item['cpfparticipante'] ?? '');
    final horarioLimiteEntrada = (item['horariolimiteentradacortesia'] ?? '')
        .toString()
        .trim();

    if (token.isEmpty) {
      AppSnackBar.erro(context, 'QR Code não disponível para este item.');
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
            side: BorderSide(color: corIngresso, width: 2),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 460,
              maxHeight: MediaQuery.sizeOf(context).height * 0.90,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 56,
                    width: double.infinity,
                    color: corIngresso,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            nomeEvento,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
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
                        Text('Setor: $setor'),
                        const SizedBox(height: 4),
                        Text('Modalidade: $modalidade'),
                        if (horarioLimiteEntrada.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Text(
                              'Válido para entrada até as $horarioLimiteEntrada horas.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.deepOrange.shade700,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                        if (beneficio.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Benefício: $beneficio'),
                        ],
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: corIngresso.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: corIngresso.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text('Participante: $nomeParticipante'),
                              if (cpfParticipante.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(cpfParticipante),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Apresente seu documento de identificação.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: QrImageView(
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
                              backgroundColor: corIngresso,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Voltar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // atualizar itens e badge após retirada ou fechamento do qr
    await _atualizarIngressos();
  }

  String _primeiroTexto(
    Map<String, dynamic> item,
    List<String> chaves, {
    String padrao = '',
  }) {
    for (final chave in chaves) {
      final valor = (item[chave] ?? '').toString().trim();
      if (valor.isNotEmpty && valor.toLowerCase() != 'null') return valor;
    }
    return padrao;
  }

  Color _corIngresso(Map<String, dynamic> item) {
    final tipoPreco = (item['tipopreco'] ?? '').toString().trim().toUpperCase();
    final modalidade = (item['nmpreco'] ?? '').toString().trim().toUpperCase();
    final setor = (item['nmsetor'] ?? '').toString().trim().toLowerCase();
    final detalhes = (item['tipo_ingresso'] ?? '')
        .toString()
        .split(RegExp(r'\s*[•·]\s*'))
        .map((parte) => parte.trim())
        .where((parte) => parte.toLowerCase() != setor);
    final ehCortesia =
        tipoPreco == 'CORTESIA' ||
        modalidade == 'CORTESIA' ||
        detalhes.any((parte) => parte.toUpperCase() == 'CORTESIA');
    return ehCortesia ? Colors.green.shade700 : Colors.blue.shade700;
  }

  Object _chaveEvento(Map<String, dynamic> item) {
    final eventoId = int.tryParse('${item['evento_id'] ?? ''}');
    if (eventoId != null && eventoId > 0) return eventoId;

    // Compatibilidade com respostas anteriores à inclusão de evento_id.
    final nome = _primeiroTexto(item, const ['nmevento', 'nmproduto']);
    final horario = _primeiroTexto(item, const [
      'dtinicioevento',
      'dtinicioevento_fmt',
    ]);
    if (nome.isEmpty || horario.isEmpty) {
      return item['itvenda_id'] == null
          ? item
          : ('ingresso', '${item['itvenda_id']}');
    }
    return (
      '${item['loja_id'] ?? widget.nomeLoja}',
      nome,
      horario,
      _primeiroTexto(item, const [
        'endereco_evento_completo',
        'dsendlocevento',
        'endereco_estabelecimento',
      ]),
    );
  }

  Iterable<List<Map<String, dynamic>>> _agruparPorEvento() {
    final grupos = <Object, List<Map<String, dynamic>>>{};
    for (final item in itensTela) {
      (grupos[_chaveEvento(item)] ??= []).add(item);
    }
    return grupos.values;
  }

  Widget _eventoCard(
    List<Map<String, dynamic>> ingressos, {
    Map<String, dynamic>? eventoOriginal,
    VoidCallback? onAbrir,
    bool larguraTotal = false,
    bool mostrarInformacoesEvento = true,
  }) {
    final evento = ingressos.isEmpty ? eventoOriginal! : ingressos.first;
    final nome = _primeiroTexto(evento, const [
      'nmevento',
      'nmproduto',
    ], padrao: 'Evento');
    final horario = _primeiroTexto(evento, const [
      'dtinicioevento_fmt',
    ], padrao: 'Não informado').replaceAll(RegExp(r'\s+'), ' ');
    final local = _primeiroTexto(evento, const [
      'endereco_evento_completo',
      'dsendlocevento',
      'endereco_estabelecimento',
    ], padrao: 'Não informado');
    final quantidade = ingressos.fold<int>(
      0,
      (total, item) => total + (int.tryParse('${item['qtitvenda'] ?? 1}') ?? 1),
    );
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: larguraTotal ? double.infinity : 620,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: larguraTotal
                  ? const BorderRadius.vertical(bottom: Radius.circular(20))
                  : BorderRadius.circular(20),
              side: BorderSide(color: Colors.amber.shade200),
            ),
            child: InkWell(
              onTap: onAbrir,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _imagemItem(evento),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nome,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                quantidade == 1
                                    ? '1 ingresso'
                                    : '$quantidade ingressos',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (mostrarInformacoesEvento) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            _informacaoIngresso(
                              icone: Icons.event_outlined,
                              titulo: 'Horário evento',
                              valor: horario,
                              corIcone: Colors.blue.shade700,
                            ),
                            const SizedBox(height: 10),
                            _informacaoIngresso(
                              icone: Icons.place_outlined,
                              titulo: 'Local',
                              valor: local,
                              corIcone: Colors.blue.shade700,
                            ),
                          ],
                        ),
                      ),
                      ],
                    if (onAbrir != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ver ingressos',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.amber.shade900,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemCard(BuildContext context, Map<String, dynamic> item) {
    final nomeParticipante = (item['nmparticipante'] ?? '').toString().trim();

    final cpfOriginal = (item['cpfparticipante'] ?? '').toString().trim();

    final cpfParticipante = cpfOriginal.isEmpty
        ? ''
        : _formatarCpf(cpfOriginal);

    final historicoParticipantes =
        (item['historico_participantes'] as List? ?? [])
            .whereType<Map>()
            .map((registro) => Map<String, dynamic>.from(registro))
            .toList();
    final ultimaAlteracao = historicoParticipantes.isEmpty
        ? null
        : historicoParticipantes.last;
    final nomeAnterior = (ultimaAlteracao?['nmparticipanteanterior'] ?? '')
        .toString()
        .trim();
    final nomeNovo = (ultimaAlteracao?['nmparticipantenovo'] ?? '')
        .toString()
        .trim();

    final dataCompra = (item['dtcriacao_fmt'] ?? '').toString().trim();
    final tipoIngresso = (item['tipo_ingresso'] ?? '').toString().trim();
    final setor = (item['nmsetor'] ?? '').toString().trim();
    final modalidade = (item['nmpreco'] ?? '').toString().trim();
    final detalhesModalidade = tipoIngresso
        .split(RegExp(r'\s*[•·]\s*'))
        .map((parte) => parte.trim())
        .where(
          (parte) =>
              parte.isNotEmpty && parte.toLowerCase() != setor.toLowerCase(),
        )
        .join(' • ');
    final modalidadeExibida = detalhesModalidade.isNotEmpty
        ? detalhesModalidade
        : modalidade;
    final corIngresso = _corIngresso(item);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          key: item['itvenda_id'] == null
              ? null
              : ValueKey('ingresso-${item['itvenda_id']}'),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: corIngresso.withValues(alpha: .65)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(21),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        corIngresso.withValues(alpha: .13),
                        Colors.amber.withValues(alpha: .08),
                      ],
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          color: corIngresso,
                          size: 21,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PARTICIPANTE',
                                style: TextStyle(
                                  color: corIngresso,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .6,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                nomeParticipante.isEmpty
                                    ? 'Participante não informado'
                                    : nomeParticipante,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cpfParticipante.isEmpty
                                    ? 'CPF não informado'
                                    : 'CPF: $cpfParticipante',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                              if (nomeAnterior.isNotEmpty &&
                                  nomeNovo.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Alterado de $nomeAnterior para $nomeNovo',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Transferir participante',
                          child: SizedBox(
                            width: constraints.maxWidth < 320 ? 80 : 96,
                            child: OutlinedButton(
                              onPressed: () =>
                                  _abrirDialogAlterarParticipante(item),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: corIngresso,
                                side: BorderSide(
                                  color: corIngresso.withValues(alpha: .5),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(44, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.swap_horiz_rounded, size: 18),
                                  Text(
                                    'Transferir\nparticipante',
                                    semanticsLabel: 'Transferir participante',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: corIngresso.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.confirmation_number_outlined,
                            size: 20,
                            color: corIngresso,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  modalidadeExibida.isEmpty
                                      ? 'Ingresso'
                                      : modalidadeExibida,
                                  style: TextStyle(
                                    color: corIngresso,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Setor: ${setor.isEmpty ? 'Não informado' : setor}',
                                        style: const TextStyle(fontSize: 12),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 6,
                                      child: FittedBox(
                                        alignment: Alignment.centerLeft,
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.receipt_long_outlined, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 5),
                                            Text('Comprado em', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                            const SizedBox(width: 4),
                                            Text(dataCompra.isEmpty ? 'Não informado' : dataCompra,
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                          ],
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
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: CustomPaint(
                  size: const Size(double.infinity, 14),
                  painter: _DivisoriaIngressoPainter(corIngresso),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _compartilharIngresso(item),
                            icon: const Icon(
                              Icons.card_giftcard_rounded,
                              size: 18,
                            ),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Presentear'),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: corIngresso,
                              side: BorderSide(
                                color: corIngresso.withValues(alpha: .5),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: const Size(0, 44),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _abrirQrOuRetirada(context, item),
                            icon: const Icon(Icons.qr_code_2_rounded, size: 19),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Exibir QR Code'),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: corIngresso,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: const Size(0, 44),
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
      color: Colors.amber.withValues(alpha: 0.14),
      alignment: Alignment.center,
      child: Icon(
        Icons.confirmation_number_outlined,
        color: Colors.amber.shade800,
        size: 28,
      ),
    );
  }

  Widget _estadoVazio({bool doEvento = false}) {
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
            doEvento ? 'Não há ingressos disponíveis para este evento.' : 'Não há ingressos disponíveis para uso neste estabelecimento.',
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
    return Row(
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
              Wrap(
                spacing: 6,
                runSpacing: 3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    valor,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // A navegação entre eventos e ingressos fica dentro da carteira para
    // preservar a barra inferior e tratar o Voltar um nível por vez.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _voltar();
      },
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (_) => MaterialPageRoute(
          settings: const RouteSettings(name: 'eventos-carteira'),
          builder: (context) => ValueListenableBuilder(
            valueListenable: _itens,
            builder: (context, _, _) => _telaEventos(context),
          ),
        ),
      ),
    );
  }

  Widget _telaIngressosEvento(
    BuildContext context,
    Map<String, dynamic> evento,
    List<Map<String, dynamic>> ingressos,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: ClubbarAppBar(
        titulo: 'Meus ingressos',
        iconeTitulo: Icons.confirmation_number_outlined,
        corIconeTitulo: Colors.amber,
        mostrarVoltar: true,
        mostrarSessao: false,
        tituloAlinhadoEsquerda: true,
        onVoltar: _voltar,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _eventoCard(
            ingressos,
            eventoOriginal: evento,
            larguraTotal: true,
            mostrarInformacoesEvento: false,
          ),
          if (ingressos.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Apresente o QR Code na portaria do evento',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _atualizarIngressos,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  if (ingressos.isEmpty)
                    _estadoVazio(doEvento: true)
                  else
                    ...ingressos.map((item) => _itemCard(context, item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _telaEventos(BuildContext context) {
    final totalUnidades = itensTela.fold<int>(0, (total, item) {
      final quantidade = int.tryParse('${item['qtitvenda'] ?? 0}') ?? 0;

      return total + quantidade;
    });

    final subtituloAux = totalUnidades == 1
        ? '1 ingresso disponível'
        : '$totalUnidades ingressos disponíveis';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: ClubbarAppBar(
        titulo: 'Minha Carteira - Ingressos',
        iconeTitulo: Icons.account_balance_wallet_rounded,
        corIconeTitulo: Colors.amber,
        mostrarVoltar: true,
        mostrarSessao: false,
        tituloAlinhadoEsquerda: true,
        onVoltar: widget.onVoltar,
      ),

      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: widget.nomeLoja,
            subtitulo: subtituloAux,
            maxLinhasSubtitulo: 3,
            icone: Icons.storefront_rounded,
            imagemAvatarUrl: _buildImageUrl(widget.logoLoja),
            tamanhoAvatar: 58,
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _atualizarIngressos,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  if (itensTela.isEmpty)
                    _estadoVazio()
                  else
                    for (final ingressos in _agruparPorEvento())
                      _eventoCard(
                        ingressos,
                        onAbrir: () => _abrirEvento(ingressos.first),
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
