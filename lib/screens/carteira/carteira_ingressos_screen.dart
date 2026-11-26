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
import '../../utils/value_formatters.dart';

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
  late List<Map<String, dynamic>> itensTela;
  final ApiService apiService = ApiService();

  static final String baseUrl = AppConfig.apiBaseUrl;

  @override
  void initState() {
    super.initState();
    itensTela = _ordenarIngressos(widget.itens);
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

      setState(() {
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
      });

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
    if (widget.onAtualizar != null) {
      final novosItens = await widget.onAtualizar!();

      CarteiraBadgeNotifier.atualizar();

      if (!mounted) return;

      setState(() {
        itensTela = _ordenarIngressos(novosItens);
      });
    }
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

  Widget _itemCard(BuildContext context, Map<String, dynamic> item) {
    final nomeIngresso = (item['nmevento'] ?? item['nmproduto'] ?? 'Ingresso')
        .toString()
        .trim();

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

    final dataEvento = (item['dtinicioevento_fmt'] ?? '').toString().trim();
    final dataCompra = (item['dtcriacao_fmt'] ?? '').toString().trim();
    final valorIngresso = double.tryParse('${item['vrunititvenda'] ?? ''}');
    final taxaIngresso = double.tryParse('${item['vrtaxaitvenda'] ?? ''}');
    final quantidadeIngresso = int.tryParse('${item['qtitvenda'] ?? 1}') ?? 1;
    final valorPago = valorIngresso == null || taxaIngresso == null
        ? null
        : valorIngresso * quantidadeIngresso + taxaIngresso;
    final horarioEvento = dataEvento.replaceFirstMapped(
      RegExp(r'^(\d{2}/\d{2}/\d{4})\s+(\d{2}:\d{2}(?::\d{2})?)$'),
      (match) => '${match[1]}\n${match[2]}',
    );
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
    final enderecoEvento =
        (item['endereco_evento_completo'] ??
                item['dsendlocevento'] ??
                item['endereco_estabelecimento'] ??
                '')
            .toString()
            .trim();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        corIngresso.withValues(alpha: .13),
                        Colors.amber.withValues(alpha: .08),
                      ],
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _imagemItem(item),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nomeIngresso,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
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
                            Text(
                              'Setor: ${setor.isEmpty ? 'Não informado' : setor}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 14, 15, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _informacaoIngresso(
                          icone: Icons.event_outlined,
                          titulo: 'Horário evento',
                          valor: horarioEvento.isEmpty
                              ? 'Não informado'
                              : horarioEvento,
                          corIcone: corIngresso,
                        ),
                        const SizedBox(width: 8),
                        _informacaoIngresso(
                          icone: Icons.receipt_long_outlined,
                          titulo: 'Comprado em',
                          valor: dataCompra.isEmpty
                              ? 'Não informado'
                              : dataCompra,
                          corIcone: corIngresso,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _informacaoIngresso(
                          icone: Icons.place_outlined,
                          titulo: 'Local',
                          valor: enderecoEvento.isEmpty
                              ? 'Não informado'
                              : enderecoEvento,
                          corIcone: corIngresso,
                          flex: 3,
                        ),
                        const SizedBox(width: 8),
                        _informacaoIngresso(
                          icone: Icons.confirmation_num_outlined,
                          titulo: 'Valor pago',
                          valor: valorPago == null
                              ? 'Não informado'
                              : ValueFormatters.moeda(valorPago),
                          corIcone: corIngresso,
                          flex: 2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: corIngresso.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
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
                                    fontSize: 14,
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: CustomPaint(
                  size: const Size(double.infinity, 14),
                  painter: _DivisoriaIngressoPainter(corIngresso),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _abrirDialogAlterarParticipante(item),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Transferir participante'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: corIngresso,
                        side: BorderSide(
                          color: corIngresso.withValues(alpha: .5),
                        ),
                        minimumSize: const Size(0, 42),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                              child: Text('Presentear alguém'),
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
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
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
            subtitulo: itensTela.isEmpty
                ? subtituloAux
                : '$subtituloAux\nApresente o QR Code na portaria do evento',
            maxLinhasSubtitulo: 3,
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
                  itensTela = _ordenarIngressos(novosItens);
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
