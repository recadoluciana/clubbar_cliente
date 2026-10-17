import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/evento_detalhe.dart';
import '../../models/evento_lote.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/main_navigation_controller.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/clubbar_page_header.dart';
import '../../widgets/clubbar_contact_links.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../utils/value_formatters.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/login_redirect.dart';
import '../produtos_loja/produtos_loja_screen.dart';
import 'participantes_reserva_screen.dart';
import '../pagamento/politica_compra_screen.dart';
import 'meia_entrada_screen.dart';

const int _limiteIngressosPorTransacao = 5;
const String _mensagemLimiteIngressosPorTransacao =
    'Máximo de 5 ingressos por compra. Caso necessite de mais ingressos realize duas ou mais compras.';

bool _ehCortesia(EventoLote lote) => lote.preco <= 0;

int _limitePorTransacao(EventoLote lote) =>
    _ehCortesia(lote) ? 1 : _limiteIngressosPorTransacao;

String _textoLimitePorTransacao(EventoLote lote) => _ehCortesia(lote)
    ? 'Limite de 1 ingresso por transação'
    : 'Limite de 5 ingressos por transação';

String _mensagemLimitePorTransacao(EventoLote lote) => _ehCortesia(lote)
    ? 'Cortesia limitada a 1 ingresso por transação.'
    : _mensagemLimiteIngressosPorTransacao;

class DetalheEventoScreen extends StatefulWidget {
  final int eventoId;
  final Loja loja;
  final VoidCallback? onVoltar;

  const DetalheEventoScreen({
    super.key,
    required this.eventoId,
    required this.loja,
    this.onVoltar,
  });

  @override
  State<DetalheEventoScreen> createState() => _DetalheEventoScreenState();
}

class _ModalidadesIngressoScreen extends StatefulWidget {
  final List<EventoLote> opcoes;
  final String nomeLoja;
  final String nomeEvento;
  final String dataHoraEvento;
  final String imagemEventoUrl;
  final double taxaPercentual;
  final double taxaMinima;
  final String Function(EventoLote) nomeModalidade;
  final Future<void> Function(EventoLote lote, int quantidade) onComprar;
  final VoidCallback onEntenderTaxa;

  const _ModalidadesIngressoScreen({
    required this.opcoes,
    required this.nomeLoja,
    required this.nomeEvento,
    required this.dataHoraEvento,
    required this.imagemEventoUrl,
    required this.taxaPercentual,
    required this.taxaMinima,
    required this.nomeModalidade,
    required this.onComprar,
    required this.onEntenderTaxa,
  });

  @override
  State<_ModalidadesIngressoScreen> createState() =>
      _ModalidadesIngressoScreenState();
}

class _ModalidadesIngressoScreenState
    extends State<_ModalidadesIngressoScreen> {
  final Map<int, int> _quantidades = {};
  bool _processando = false;

  @override
  Widget build(BuildContext context) {
    final lote = widget.opcoes.first;
    final vendaDisponivel = lote.podeComprarEm(DateTime.now());
    final nomeSetor = lote.nomeSetor.trim();
    final descricaoSetor = lote.descricaoSetor.trim();
    final descricaoPadrao =
        descricaoSetor.toLowerCase() ==
        'setor ${nomeSetor.toLowerCase()} do evento';
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: ClubbarAppBar(
        titulo: widget.nomeLoja,
        mostrarVoltar: true,
        mostrarSessao: false,
      ),
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: widget.nomeEvento.trim().isEmpty
                ? 'Escolha a modalidade'
                : widget.nomeEvento,
            subtitulo: widget.dataHoraEvento,
            icone: Icons.confirmation_number_rounded,
            imagemAvatarUrl: widget.imagemEventoUrl,
            tamanhoAvatar: 56,
            larguraAvatar: 86,
            avatarRetangular: true,
            corTitulo: Colors.black87,
            maxLinhasTitulo: 2,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (descricaoSetor.isNotEmpty && !descricaoPadrao) ...[
                  Text(
                    descricaoSetor,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                ],
                ...widget.opcoes.map(
                  (opcao) =>
                      _cardModalidade(opcao, vendaDisponivel: vendaDisponivel),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton.icon(
                    onPressed: widget.onEntenderTaxa,
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text(
                      'Entenda nossa taxa',
                      style: TextStyle(fontWeight: FontWeight.normal),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardModalidade(EventoLote lote, {required bool vendaDisponivel}) {
    final quantidade = _quantidades[lote.lotePrecoId] ?? 1;
    final ehCortesia = _ehCortesia(lote);
    final ehMeiaLegal = lote.aplicaCotaLegal;
    final disponivelModalidade = lote.qtDisponivelParaCompra;
    final modalidadeDisponivel = disponivelModalidade > 0;
    final podeDiminuir = quantidade > 1;
    final podeAumentar =
        quantidade < _limitePorTransacao(lote) &&
        quantidade < disponivelModalidade;
    final taxaPercentual = lote.preco * widget.taxaPercentual / 100;
    final taxaUnitaria = lote.preco <= 0
        ? 0.0
        : (taxaPercentual > widget.taxaMinima
              ? taxaPercentual
              : widget.taxaMinima);
    final totalPagar = (lote.preco + taxaUnitaria) * quantidade;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ehMeiaLegal)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.nomeModalidade(lote),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MeiaEntradaScreen(),
                      ),
                    ),
                    icon: const Icon(
                      Icons.workspace_premium_outlined,
                      size: 16,
                    ),
                    label: const Text('Quem tem direito'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              )
            else
              Text(
                widget.nomeModalidade(lote),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            if (lote.exigeComprovante)
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text(
                  'Comprovante obrigatório',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            if (ehMeiaLegal) ...[
              const SizedBox(height: 6),
              Text(
                'Cota legal do evento: ${lote.cotaLegal} ingresso${lote.cotaLegal == 1 ? '' : 's'} (${lote.percentualCotaLegal == lote.percentualCotaLegal.roundToDouble() ? lote.percentualCotaLegal.toInt() : lote.percentualCotaLegal}% da capacidade)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$disponivelModalidade ingresso${disponivelModalidade == 1 ? '' : 's'} disponíve${disponivelModalidade == 1 ? 'l' : 'is'} ${lote.qtLimiteModalidade == null ? 'nesta cota' : 'nesta modalidade'}',
                style: TextStyle(
                  fontSize: 12,
                  color: disponivelModalidade > 0
                      ? Colors.green.shade700
                      : Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                '$disponivelModalidade ingresso${disponivelModalidade == 1 ? '' : 's'} disponíve${disponivelModalidade == 1 ? 'l' : 'is'} nesta modalidade',
                style: TextStyle(
                  fontSize: 12,
                  color: disponivelModalidade > 0
                      ? Colors.green.shade700
                      : Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 3),
            Text(
              _textoLimitePorTransacao(lote),
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${ValueFormatters.moeda(lote.preco)} (+${ValueFormatters.moeda(taxaUnitaria).replaceFirst('R\$ ', '')} taxa)',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _controleQuantidade(
                  lote: lote,
                  quantidade: quantidade,
                  podeDiminuir: podeDiminuir,
                  podeAumentar: podeAumentar,
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                const Text(
                  'Total a pagar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  ValueFormatters.moeda(totalPagar),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    !vendaDisponivel || _processando || !modalidadeDisponivel
                    ? null
                    : () async {
                        setState(() => _processando = true);
                        try {
                          await widget.onComprar(lote, quantidade);
                        } finally {
                          if (mounted) setState(() => _processando = false);
                        }
                      },
                icon: const Icon(Icons.local_activity_outlined),
                label: Text(ehCortesia ? 'Resgatar' : 'Comprar ingresso'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amareloCerveja,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controleQuantidade({
    required EventoLote lote,
    required int quantidade,
    required bool podeDiminuir,
    required bool podeAumentar,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Diminuir quantidade',
            onPressed: !podeDiminuir
                ? null
                : () => setState(
                    () => _quantidades[lote.lotePrecoId] = quantidade - 1,
                  ),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded, size: 19),
          ),
          Text(
            '$quantidade',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          IconButton(
            tooltip: 'Aumentar quantidade',
            onPressed: !podeAumentar
                ? null
                : () {
                    if (quantidade >= _limitePorTransacao(lote)) {
                      AppSnackBar.aviso(
                        context,
                        _mensagemLimitePorTransacao(lote),
                      );
                      return;
                    }
                    setState(
                      () => _quantidades[lote.lotePrecoId] = quantidade + 1,
                    );
                  },
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _DetalheEventoScreenState extends State<DetalheEventoScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();
  final Map<int, Map<String, dynamic>> _statusLotes = {};
  final GlobalKey _ingressosKey = GlobalKey();

  bool carregando = true;
  bool atualizandoLotes = false;
  bool processandoCompra = false;
  String? erro;

  EventoDetalhe? evento;
  List<EventoLote> lotes = [];
  final Map<int, int> _quantidadesModalidades = {};

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarStatusLotes() async {
    for (final lote in lotes) {
      try {
        final dados = await apiService.buscarQuantidadeVendidaLote(
          loteId: lote.loteId,
        );

        _statusLotes[lote.loteId] = dados;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> atualizarLotes() async {
    if (atualizandoLotes) return;
    setState(() => atualizandoLotes = true);
    try {
      final listaLotes = await apiService.buscarLotesDoEvento(widget.eventoId);
      if (!mounted) return;
      setState(() {
        lotes = listaLotes;
        _statusLotes.clear();
      });
      await carregarStatusLotes();
      if (mounted) {
        AppSnackBar.sucesso(context, 'Informações dos lotes atualizadas.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, apiService.mensagemErroAmigavel(e));
      }
    } finally {
      if (mounted) setState(() => atualizandoLotes = false);
    }
  }

  Future<void> _irParaIngressos() async {
    final contextoIngressos = _ingressosKey.currentContext;
    if (contextoIngressos == null) return;

    await Scrollable.ensureVisible(
      contextoIngressos,
      alignment: 0.08,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> compartilharEvento() async {
    final ev = evento;
    if (ev == null) return;

    final texto =
        '''
  🎟️ ${ev.titulo}

  📅 ${DateFormatters.dataHoraSimples(ev.dataInicio)}

  📍 ${ev.local}
  🏙️ ${ev.nomeCidade}${ev.sgEstado.trim().isEmpty ? '' : ' - ${ev.sgEstado}'}

  🍻 Garanta seu ingresso pelo Clubbar

  👉 Acesse:
  ${AppConfig.appWebUrl}/?evento_id=${widget.eventoId}&loja_id=${widget.loja.id}

  🦉 Clubbar
  Compre seu ingresso e o que vai consumir
  ''';

    await Share.share(texto);
  }

  Future<void> carregarDados() async {
    setState(() {
      carregando = true;
      erro = null;
      _statusLotes.clear();
    });

    try {
      final resultados = await Future.wait([
        apiService.buscarDetalheEvento(widget.eventoId),
        apiService.buscarLotesDoEvento(widget.eventoId),
      ]);

      final detalhe = resultados[0] as EventoDetalhe;
      final listaLotes = resultados[1] as List<EventoLote>;

      if (!mounted) return;
      setState(() {
        evento = detalhe;
        lotes = listaLotes;
        carregando = false;
      });
      await carregarStatusLotes();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '');
        carregando = false;
      });
    }
  }

  String formatarDataHora(String valor) {
    return DateFormatters.dataCompleta(valor);
  }

  String formatarPeriodoVenda(String inicio, String fim) {
    return DateFormatters.periodo(inicio, fim);
  }

  MaterialColor _corEstilo(int indice) {
    const cores = [
      Colors.blue,
      Colors.purple,
      Colors.green,
      Colors.deepOrange,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return cores[indice % cores.length];
  }

  Widget _badgesEstilos(AtracaoEventoDetalhe atracao) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: atracao.estilos.asMap().entries.map((item) {
        final cor = _corEstilo(item.key);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cor.withValues(alpha: .45)),
          ),
          child: Text(
            item.value,
            style: TextStyle(
              color: cor.shade700,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _fotoAtracao(AtracaoEventoDetalhe atracao, {double tamanho = 48}) {
    final imagem = atracao.bannerUrl.trim();
    return ClipOval(
      child: SizedBox(
        width: tamanho,
        height: tamanho,
        child: imagem.isEmpty
            ? Container(
                color: Colors.blue.shade50,
                child: Icon(
                  Icons.music_note_rounded,
                  color: Colors.blue.shade700,
                  size: tamanho / 2,
                ),
              )
            : Image.network(
                imagem,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.blue.shade50,
                  child: Icon(
                    Icons.music_note_rounded,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
              ),
      ),
    );
  }

  void _abrirDetalhesAtracao(AtracaoEventoDetalhe atracao) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              if (atracao.bannerUrl.trim().isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      atracao.bannerUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.blue.shade50,
                        child: Icon(
                          Icons.music_note_rounded,
                          size: 54,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Text(
                atracao.nome,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (atracao.estilos.isNotEmpty) ...[
                const SizedBox(height: 10),
                _badgesEstilos(atracao),
              ],
              if (atracao.descricao.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Sobre a atração',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  atracao.descricao,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<int?> _obterClienteIdLogado() async {
    final clienteId = await authStorage.obterClienteId();
    if (!mounted) return null;

    if (clienteId == null || clienteId == 0) {
      await direcionarParaLogin(context);
      return null;
    }

    return clienteId;
  }

  Future<void> iniciarReserva(
    EventoLote lote, {
    int? quantidadeSelecionada,
  }) async {
    if (processandoCompra) return;
    if (lote.qtDisponivelParaCompra <= 0) {
      await carregarStatusLotes();
      if (mounted) {
        AppSnackBar.aviso(
          context,
          'Este lote acabou de esgotar. Atualizamos as opções disponíveis.',
        );
      }
      return;
    }
    var quantidade = quantidadeSelecionada ?? 1;
    final limitePorTransacao = _limitePorTransacao(lote);
    bool? confirmada = quantidadeSelecionada != null;
    if (quantidadeSelecionada == null) {
      confirmada = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Comprar ingressos'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lote.nome,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Quantos participantes?'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: quantidade > 1
                          ? () => setDialogState(() => quantidade--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$quantidade',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed:
                          quantidade < limitePorTransacao &&
                              quantidade < lote.qtDisponivelParaCompra
                          ? () {
                              if (quantidade >= limitePorTransacao) {
                                AppSnackBar.aviso(
                                  dialogContext,
                                  _mensagemLimitePorTransacao(lote),
                                );
                                return;
                              }
                              setDialogState(() => quantidade++);
                            }
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        ),
      );
    }
    if (confirmada != true || !mounted) return;
    if (quantidade > limitePorTransacao) {
      AppSnackBar.aviso(context, _mensagemLimitePorTransacao(lote));
      return;
    }
    if (quantidade > lote.qtDisponivelParaCompra) {
      await carregarStatusLotes();
      if (mounted) {
        AppSnackBar.aviso(
          context,
          'A quantidade escolhida não está mais disponível neste lote.',
        );
      }
      return;
    }
    setState(() => processandoCompra = true);
    try {
      final clienteId = await _obterClienteIdLogado();
      if (clienteId == null) return;
      final reserva = await apiService.criarReservaIngresso(
        clienteId: clienteId,
        loteId: lote.loteId,
        lotePrecoId: lote.lotePrecoId,
        quantidade: quantidade,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ParticipantesReservaScreen(
            loja: widget.loja,
            reserva: reserva,
            nomeEvento: evento?.titulo ?? lote.nome,
            dataHoraEvento: DateFormatters.dataHoraSimples(
              evento?.dataInicio ?? '',
            ),
            imagemEventoUrl: evento?.bannerUrl ?? '',
            nomeLote: lote.nome,
            nomeSetor: lote.nomeSetor.trim().isEmpty
                ? 'Setor não informado'
                : lote.nomeSetor,
            modalidade: _nomeModalidade(lote),
            beneficios: lote.beneficios,
          ),
        ),
      );
      await carregarStatusLotes();
    } catch (e) {
      if (mounted) {
        if (apiService.erroDeSessao(e)) {
          await authStorage.limparToken();
          if (mounted) {
            await direcionarParaLogin(
              context,
              mensagem:
                  'Sua sessão terminou. Entre novamente para comprar seu ingresso.',
            );
          }
          return;
        }
        final mensagem = apiService.mensagemErroAmigavel(e);
        if (lote.aplicaCotaLegal &&
            mensagem.toLowerCase().contains('cota legal')) {
          AppSnackBar.erro(
            context,
            'A cota legal de meia-entrada foi atingida. '
            'Cota do evento: ${lote.cotaLegal} ingresso${lote.cotaLegal == 1 ? '' : 's'}; '
            'disponíveis agora: ${lote.qtDisponivelCotaLegal}.',
          );
        } else {
          AppSnackBar.erro(context, mensagem);
        }
      }
    } finally {
      if (mounted) setState(() => processandoCompra = false);
    }
  }

  Widget linhaInfo({
    required IconData icone,
    required String titulo,
    required String valor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: Colors.black87),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$titulo: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: valor.trim().isEmpty ? 'Não informado' : valor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<List<List<EventoLote>>> get _lotesGlobaisAgrupados {
    final porGlobal = <int, List<EventoLote>>{};
    for (final lote in lotes) {
      porGlobal
          .putIfAbsent(
            lote.loteGlobalId == 0 ? lote.loteId : lote.loteGlobalId,
            () => [],
          )
          .add(lote);
    }
    return porGlobal.values.map((opcoesDoGlobal) {
      final porSetor = <int, List<EventoLote>>{};
      for (final opcao in opcoesDoGlobal) {
        porSetor.putIfAbsent(opcao.loteId, () => []).add(opcao);
      }
      return porSetor.values.toList();
    }).toList();
  }

  String _nomeModalidade(EventoLote lote) {
    return lote.nomeModalidade.trim().isEmpty
        ? 'Ingresso'
        : lote.nomeModalidade;
  }

  Widget cardLoteGlobal(
    List<List<EventoLote>> setores, {
    required bool exibirNomeLote,
    required bool exibirNomeSetor,
  }) {
    final lote = setores.first.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exibirNomeLote) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
              child: Text(
                'Lote: ${lote.nome}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
          ...setores.map(
            (opcoes) => cardLote(
              opcoes,
              exibirNomeLote: false,
              exibirNomeSetor: exibirNomeSetor,
            ),
          ),
        ],
      ),
    );
  }

  Widget cardLote(
    List<EventoLote> opcoes, {
    bool exibirNomeLote = true,
    bool exibirNomeSetor = true,
  }) {
    final lote = opcoes.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exibirNomeLote)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 4),
              child: Text(
                lote.nome,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (exibirNomeSetor && lote.nomeSetor.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 6),
              child: Text(
                'Setor: ${lote.nomeSetor}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
              ),
            ),
          ...opcoes.map(_cardModalidadeDireta),
        ],
      ),
    );
  }

  Widget _cardModalidadeDireta(EventoLote lote) {
    final quantidade = _quantidadesModalidades[lote.lotePrecoId] ?? 1;
    final ehCortesia = _ehCortesia(lote);
    final ehMeiaLegal = lote.aplicaCotaLegal;
    final vendaDisponivel = lote.podeComprarEm(DateTime.now());
    final disponivel = lote.qtDisponivelParaCompra;
    final modalidadeDisponivel = disponivel > 0;
    final cortesiaEsgotada = ehCortesia && !modalidadeDisponivel;
    final taxaPercentual = lote.preco * widget.loja.vrtaxaing / 100;
    final taxa = lote.preco <= 0
        ? 0.0
        : (taxaPercentual > widget.loja.vrtaxaminimaingresso
              ? taxaPercentual
              : widget.loja.vrtaxaminimaingresso);
    final total = (lote.preco + taxa) * quantidade;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _nomeModalidade(lote),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (ehMeiaLegal)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MeiaEntradaScreen(),
                      ),
                    ),
                    child: const Text('Quem tem direito'),
                  ),
              ],
            ),
            if (cortesiaEsgotada)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Text(
                    'Cortesias esgotadas',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            if (lote.exigeComprovante)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  'Comprovante obrigatório',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            if (ehCortesia && lote.horarioLimiteEntrada != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Válido para entrada até as ${lote.horarioLimiteEntrada} horas.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.deepOrange.shade700,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              '$disponivel ingresso${disponivel == 1 ? '' : 's'} disponíve${disponivel == 1 ? 'l' : 'is'} ${ehMeiaLegal && lote.qtLimiteModalidade == null ? 'nesta cota' : 'nesta modalidade'}',
              style: TextStyle(
                fontSize: 12,
                color: modalidadeDisponivel
                    ? Colors.green.shade700
                    : Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _textoLimitePorTransacao(lote),
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${ValueFormatters.moeda(lote.preco)} (+${ValueFormatters.moeda(taxa).replaceFirst('R\$ ', '')} taxa)',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _controleQuantidadeModalidade(
                  lote: lote,
                  quantidade: quantidade,
                  disponibilidade: disponivel,
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                const Text(
                  'Total a pagar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  ValueFormatters.moeda(total),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    !vendaDisponivel ||
                        processandoCompra ||
                        !modalidadeDisponivel
                    ? null
                    : () => iniciarReserva(
                        lote,
                        quantidadeSelecionada: quantidade,
                      ),
                icon: const Icon(Icons.local_activity_outlined),
                label: Text(ehCortesia ? 'Resgatar' : 'Comprar ingresso'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amareloCerveja,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controleQuantidadeModalidade({
    required EventoLote lote,
    required int quantidade,
    required int disponibilidade,
  }) {
    final podeAumentar =
        quantidade < disponibilidade && quantidade < _limitePorTransacao(lote);
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Diminuir quantidade',
            onPressed: quantidade > 1
                ? () => setState(
                    () => _quantidadesModalidades[lote.lotePrecoId] =
                        quantidade - 1,
                  )
                : null,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded, size: 19),
          ),
          Text(
            '$quantidade',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          IconButton(
            tooltip: 'Aumentar quantidade',
            onPressed: !podeAumentar
                ? null
                : () => setState(
                    () => _quantidadesModalidades[lote.lotePrecoId] =
                        quantidade + 1,
                  ),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  Widget estadoErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 60),
            const SizedBox(height: 14),
            Text(
              erro ?? 'Erro ao carregar evento',
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

  Widget estadoVazioLotes() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            Icons.local_activity_outlined,
            size: 54,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'Nenhum lote disponível',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirReferenciaTaxas() async {
    final abriu = await launchUrl(
      Uri.parse(
        'https://www.stj.jus.br/sites/portalp/Paginas/Comunicacao/Noticias/15102020-STJ-readequa-entendimento-sobre-abuso-da-taxa-de-conveniencia-em-venda-de-ingressos-pela-internet.aspx',
      ),
      mode: LaunchMode.externalApplication,
    );
    if (!abriu && mounted) {
      AppSnackBar.erro(context, 'Não foi possível abrir a referência.');
    }
  }

  Widget _itemTaxa(String titulo, String descricao) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 14,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: '$titulo: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: descricao),
          ],
        ),
      ),
    );
  }

  void _abrirExplicacaoTaxas() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.74,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(Icons.receipt_long_outlined, color: Colors.amber),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Entenda as taxas da compra',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'No Clubbar, os valores aplicáveis são apresentados antes da confirmação do pedido. Eles ajudam a viabilizar a experiência de compra e o processamento seguro do pagamento.',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Taxa de serviço',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              Text(
                'É o valor destinado à estrutura que torna a venda e o acompanhamento do ingresso possíveis.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              _itemTaxa(
                'Plataforma Clubbar',
                'manutenção, disponibilidade e evolução do site e do aplicativo.',
              ),
              _itemTaxa(
                'Gestão da compra',
                'proteção das informações, emissão do ingresso digital, acompanhamento do pedido e suporte.',
              ),
              _itemTaxa(
                'Recursos do evento',
                'funcionalidades necessárias à venda, conforme a configuração da produção.',
              ),
              const SizedBox(height: 22),
              const Text(
                'Taxa de processamento',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              Text(
                'Está ligada à forma de pagamento escolhida e é destinada às instituições que autorizam e processam a transação.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              _itemTaxa(
                'Transação financeira',
                'custos de autorização e operação de cada pagamento.',
              ),
              _itemTaxa(
                'Segurança',
                'tecnologias e controles que protegem os dados e a operação financeira.',
              ),
              const SizedBox(height: 22),
              const Text(
                'Parcelamento e transparência',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'As taxas podem variar conforme o meio de pagamento, a operadora e as condições de parcelamento. Quando houver custo de parcelamento, ele será informado antes da confirmação e você poderá escolher a opção que preferir.',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'O total da compra, com as taxas aplicáveis, sempre é exibido antes do pagamento — uma medida de transparência alinhada ao entendimento do STJ sobre a cobrança de conveniência na venda online de ingressos.',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _abrirReferenciaTaxas,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Consultar orientação do STJ'),
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _politicaEvento() {
    final detalhe = evento;
    final corRodape = Theme.of(context).colorScheme.primary;
    final emailEstabelecimento = _primeiroContato(
      detalhe?.emailEstabelecimento,
      widget.loja.emailContato,
    );
    final whatsappEstabelecimento = _primeiroContato(
      detalhe?.whatsappEstabelecimento,
      widget.loja.whatsapp,
      widget.loja.nrtelloja,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PoliticaCompraScreen(tipo: 'INGRESSO'),
                ),
              ),
              icon: const Icon(Icons.policy_outlined, size: 19),
              label: const Text(
                'Política de compra de ingresso',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
              ),
              style: TextButton.styleFrom(
                foregroundColor: corRodape,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          if (detalhe != null)
            Center(
              child: ClubbarContactLinks(
                emailEstabelecimento: emailEstabelecimento,
                whatsappEstabelecimento: whatsappEstabelecimento,
                emailEvento: detalhe.emailEvento,
                whatsappEvento: detalhe.whatsappEvento,
                mostrarContatoEvento: true,
                centralizado: true,
                tamanhoFonteLinks: 12,
                tituloEmNegrito: false,
                cor: corRodape,
              ),
            ),
        ],
      ),
    );
  }

  String _primeiroContato(String? principal, [String? reserva, String? extra]) {
    for (final contato in [principal, reserva, extra]) {
      final valor = (contato ?? '').trim();
      if (valor.isNotEmpty) return valor;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final ev = evento;
    final atracoesOrdenadas = [...?ev?.atracoes]
      ..sort((a, b) {
        final inicioA = DateTime.tryParse(a.inicio);
        final inicioB = DateTime.tryParse(b.inicio);
        if (inicioA == null || inicioB == null) {
          return a.inicio.compareTo(b.inicio);
        }
        return inicioA.compareTo(inicioB);
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: ClubbarAppBar(
        titulo: 'Evento - ${widget.loja.nome}',
        mostrarVoltar: true,
        mostrarSessao: false,
        onVoltar: widget.onVoltar,
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro != null || ev == null
          ? estadoErro()
          : RefreshIndicator(
              onRefresh: carregarDados,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: ev.bannerUrl.trim().isNotEmpty
                                ? SizedBox(
                                    height: 200,
                                    child: Image.network(
                                      ev.bannerUrl,
                                      width: double.infinity,
                                      fit: BoxFit.fill,
                                    ),
                                  )
                                : SizedBox(
                                    height: 200,
                                    child: Container(
                                      color: Colors.grey.shade300,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -22),
                            child: Center(
                              child: ElevatedButton.icon(
                                onPressed: compartilharEvento,
                                icon: const Icon(Icons.ios_share, size: 18),
                                label: const Text('COMPARTILHAR'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue,
                                  elevation: 4,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ev.nomeLoja,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: () {
                                  MainNavigationController.abrirTela(
                                    ProdutosLojaScreen(loja: widget.loja),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  minimumSize: const Size(0, 40),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(
                                  Icons.restaurant_menu_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Comprar produto',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (lotes.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _irParaIngressos,
                                icon: const Icon(
                                  Icons.confirmation_number_outlined,
                                  size: 17,
                                ),
                                label: const Text('Comprar ingresso'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.amber.shade900,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            ev.titulo,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (ev.jaIniciado) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Evento já iniciado',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            formatarDataHora(ev.dataInicio),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          if (ev.dataFim.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'até ${formatarDataHora(ev.dataFim)}',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (ev.local.trim().isNotEmpty &&
                              ev.local.trim().toLowerCase() !=
                                  ev.nomeLoja.trim().toLowerCase()) ...[
                            Text(
                              ev.local,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            [
                              [
                                ev.endereco.trim(),
                                ev.numeroEndereco.trim(),
                              ].where((parte) => parte.isNotEmpty).join(', '),
                              ev.bairro.trim(),
                              ev.sgEstado.trim().isEmpty
                                  ? ev.nomeCidade.trim()
                                  : '${ev.nomeCidade.trim()} - ${ev.sgEstado.trim()}',
                            ].where((parte) => parte.isNotEmpty).join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          if (atracoesOrdenadas.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              atracoesOrdenadas.length == 1
                                  ? 'Atração'
                                  : 'Atrações',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 148,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: atracoesOrdenadas.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final atracao = atracoesOrdenadas[index];
                                  return SizedBox(
                                    width: 128,
                                    child: Material(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      child: InkWell(
                                        onTap: () =>
                                            _abrirDetalhesAtracao(atracao),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Colors.blue.shade600,
                                              width: 1.4,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                atracao.nome,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                  height: 1.15,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              _fotoAtracao(
                                                atracao,
                                                tamanho: 56,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                atracao.estilos.join(' • '),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.blue.shade700,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),
                          Container(
                            key: _ingressosKey,
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Ingressos',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: atualizandoLotes
                                      ? null
                                      : atualizarLotes,
                                  icon: atualizandoLotes
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.refresh, size: 18),
                                  label: const Text('Atualizar ingressos'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          if (lotes.isEmpty)
                            estadoVazioLotes()
                          else ...[
                            ..._lotesGlobaisAgrupados.map(
                              (setores) => cardLoteGlobal(
                                setores,
                                exibirNomeLote: true,
                                exibirNomeSetor: true,
                              ),
                            ),
                            Center(
                              child: TextButton.icon(
                                onPressed: _abrirExplicacaoTaxas,
                                icon: const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 18,
                                ),
                                label: const Text('Entenda nossa taxa'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  textStyle: const TextStyle(fontSize: 12),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ],
                          _politicaEvento(),
                          if (ev.descricao.trim().isNotEmpty &&
                              ev.descricao.trim().toLowerCase() != 'null') ...[
                            const SizedBox(height: 20),
                            const Text(
                              'Descrição',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Text(
                                ev.descricao,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade800,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
