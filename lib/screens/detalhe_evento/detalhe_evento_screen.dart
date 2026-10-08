import 'package:flutter/material.dart';

import '../../models/evento_detalhe.dart';
import '../../models/evento_lote.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/main_navigation_controller.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/clubbar_app_bar.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../utils/value_formatters.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/login_redirect.dart';
import '../produtos_loja/produtos_loja_screen.dart';
import 'participantes_reserva_screen.dart';
import '../pagamento/politica_compra_screen.dart';

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
  final double taxaPercentual;
  final double taxaMinima;
  final String Function(EventoLote) nomeModalidade;
  final Future<void> Function(EventoLote lote, int quantidade) onComprar;

  const _ModalidadesIngressoScreen({
    required this.opcoes,
    required this.taxaPercentual,
    required this.taxaMinima,
    required this.nomeModalidade,
    required this.onComprar,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Escolha a modalidade')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            lote.nomeSetor.isEmpty ? 'Setor' : lote.nomeSetor,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          if (lote.descricaoSetor.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              lote.descricaoSetor.trim(),
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${lote.nome} • ${lote.situacaoVendaEm(DateTime.now())}',
            style: TextStyle(
              color: vendaDisponivel ? Colors.green.shade700 : Colors.red,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          ...widget.opcoes.map(
            (opcao) => _cardModalidade(opcao, vendaDisponivel: vendaDisponivel),
          ),
        ],
      ),
    );
  }

  Widget _cardModalidade(EventoLote lote, {required bool vendaDisponivel}) {
    final quantidade = _quantidades[lote.lotePrecoId] ?? 1;
    final ehMeiaLegal = lote.aplicaCotaLegal;
    final disponivelModalidade = ehMeiaLegal
        ? lote.qtDisponivelCotaLegal
        : lote.qtDisponivel;
    final modalidadeDisponivel = !ehMeiaLegal || disponivelModalidade > 0;
    final podeDiminuir = quantidade > 1;
    final podeAumentar =
        quantidade < 20 &&
        quantidade < lote.qtDisponivel &&
        (!ehMeiaLegal || quantidade < disponivelModalidade);
    final taxaPercentual = lote.preco * widget.taxaPercentual / 100;
    final taxaUnitaria = lote.preco <= 0
        ? 0.0
        : (taxaPercentual > widget.taxaMinima
              ? taxaPercentual
              : widget.taxaMinima);
    final totalPagar = (lote.preco + taxaUnitaria) * quantidade;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.nomeModalidade(lote),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
              const SizedBox(height: 8),
              Text(
                'Cota legal do evento: ${lote.cotaLegal} ingresso${lote.cotaLegal == 1 ? '' : 's'} (${lote.percentualCotaLegal == lote.percentualCotaLegal.roundToDouble() ? lote.percentualCotaLegal.toInt() : lote.percentualCotaLegal}% da capacidade)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${lote.qtDisponivelCotaLegal} ingresso${lote.qtDisponivelCotaLegal == 1 ? '' : 's'} disponíve${lote.qtDisponivelCotaLegal == 1 ? 'l' : 'is'} nesta cota',
                style: TextStyle(
                  fontSize: 12,
                  color: lote.qtDisponivelCotaLegal > 0
                      ? Colors.green.shade700
                      : Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                '${disponivelModalidade} ingresso${disponivelModalidade == 1 ? '' : 's'} disponíve${disponivelModalidade == 1 ? 'l' : 'is'} nesta modalidade',
                style: TextStyle(
                  fontSize: 12,
                  color: disponivelModalidade > 0
                      ? Colors.green.shade700
                      : Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${ValueFormatters.moeda(lote.preco)} (+${ValueFormatters.moeda(taxaUnitaria).replaceFirst('R\$ ', '')} taxa)',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('Quantidade'),
                const Spacer(),
                IconButton.filled(
                  tooltip: 'Diminuir quantidade',
                  onPressed: !podeDiminuir
                      ? null
                      : () => setState(
                          () => _quantidades[lote.lotePrecoId] = quantidade - 1,
                        ),
                  icon: Text(
                    '−',
                    style: TextStyle(
                      color: podeDiminuir ? Colors.black : Colors.grey.shade700,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.amareloCerveja,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '$quantidade',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Aumentar quantidade',
                  onPressed: !podeAumentar
                      ? null
                      : () => setState(
                          () => _quantidades[lote.lotePrecoId] = quantidade + 1,
                        ),
                  icon: Text(
                    '+',
                    style: TextStyle(
                      color: podeAumentar ? Colors.black : Colors.grey.shade700,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.amareloCerveja,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
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
            const SizedBox(height: 12),
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
                label: const Text('Comprar ingresso'),
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
}

class _DetalheEventoScreenState extends State<DetalheEventoScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();
  final Map<int, Map<String, dynamic>> _statusLotes = {};

  bool carregando = true;
  bool atualizandoLotes = false;
  bool processandoCompra = false;
  String? erro;

  EventoDetalhe? evento;
  List<EventoLote> lotes = [];

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
      spacing: 6,
      runSpacing: 6,
      children: atracao.estilos.asMap().entries.map((item) {
        final cor = _corEstilo(item.key);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cor.withValues(alpha: .45)),
          ),
          child: Text(
            item.value,
            style: TextStyle(
              color: cor.shade700,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _numeroAtracao(int indice) {
    final cor = _corEstilo(indice);
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: cor.shade100, shape: BoxShape.circle),
      child: Text(
        '${indice + 1}',
        style: TextStyle(
          color: cor.shade700,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _fotoAtracao(AtracaoEventoDetalhe atracao) {
    final imagem = atracao.bannerUrl.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 68,
        height: 68,
        child: imagem.isEmpty
            ? Container(
                color: Colors.blue.shade50,
                child: Icon(
                  Icons.music_note_rounded,
                  color: Colors.blue.shade700,
                  size: 30,
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
                    size: 30,
                  ),
                ),
              ),
      ),
    );
  }

  String _duracaoPrevista(AtracaoEventoDetalhe atracao) {
    try {
      final inicio = DateTime.parse(atracao.inicio).toLocal();
      final fim = DateTime.parse(atracao.fim).toLocal();
      final duracao = fim.difference(inicio);
      if (duracao.inMinutes <= 0) return 'Duração prevista não informada';

      final horas = duracao.inHours;
      final minutos = duracao.inMinutes.remainder(60);
      final texto = horas == 0
          ? '$minutos min'
          : minutos == 0
          ? '${horas}h'
          : '${horas}h ${minutos}min';
      return 'Duração prevista: $texto';
    } catch (_) {
      return 'Duração prevista não informada';
    }
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
    if (lote.qtDisponivel <= 0) {
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
                          quantidade < 20 && quantidade < lote.qtDisponivel
                          ? () => setDialogState(() => quantidade++)
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
    if (quantidade > lote.qtDisponivel) {
      await carregarStatusLotes();
      if (mounted) {
        AppSnackBar.aviso(
          context,
          'A quantidade escolhida não está mais disponível neste lote.',
        );
      }
      return;
    }
    BeneficioIngresso? beneficio;
    if (lote.exigeBeneficio || lote.aplicaCotaLegal) {
      beneficio = await showDialog<BeneficioIngresso>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('Qual é o benefício?'),
          children: [
            for (final item in lote.beneficios)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, item),
                child: Text(item.nome),
              ),
          ],
        ),
      );
      if (beneficio == null || !mounted) return;
    }
    setState(() => processandoCompra = true);
    try {
      final clienteId = await _obterClienteIdLogado();
      if (clienteId == null) return;
      final reserva = await apiService.criarReservaIngresso(
        clienteId: clienteId,
        loteId: lote.loteId,
        lotePrecoId: lote.lotePrecoId,
        beneficioId: beneficio?.id,
        tipoBeneficio: beneficio?.codigo,
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
            nomeLote: lote.nome,
            nomeSetor: lote.nomeSetor.trim().isEmpty
                ? 'Setor não informado'
                : lote.nomeSetor,
            modalidade: _nomeModalidade(lote),
            beneficio: beneficio?.nome ?? 'Não se aplica',
          ),
        ),
      );
      await carregarStatusLotes();
    } catch (e) {
      if (mounted) {
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

  Widget cardLoteGlobal(List<List<EventoLote>> setores) {
    final lote = setores.first.first;
    final situacao = lote.situacaoVendaEm(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lote.nome,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          if (situacao == 'Disponível' || situacao == 'Em breve') ...[
            const SizedBox(height: 3),
            Text(
              situacao == 'Disponível'
                  ? 'Preço vigente para todos os setores'
                  : 'Próximo preço',
              style: TextStyle(
                color: Colors.green.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...setores.map((opcoes) => cardLote(opcoes, exibirNomeLote: false)),
        ],
      ),
    );
  }

  Widget cardLote(List<EventoLote> opcoes, {bool exibirNomeLote = true}) {
    final lote = opcoes.first;
    final agora = DateTime.now();
    final vendaDisponivel = lote.podeComprarEm(agora);
    final textoBadge = lote.situacaoVendaEm(agora);
    final vendaFutura = textoBadge == 'Em breve';
    final corBadge = vendaDisponivel
        ? Colors.green
        : vendaFutura
        ? Colors.amber.shade800
        : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (exibirNomeLote)
                          Text(
                            lote.nome,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        if (lote.nomeSetor.isNotEmpty) ...[
                          if (exibirNomeLote) const SizedBox(height: 3),
                          Text(
                            lote.nomeSetor,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: corBadge.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      textoBadge,
                      style: TextStyle(
                        color: corBadge,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                vendaDisponivel
                    ? '${lote.qtDisponivel} ingresso${lote.qtDisponivel == 1 ? '' : 's'} ${lote.qtDisponivel == 1 ? 'disponível' : 'disponíveis'} neste preço'
                    : 'Cota não utilizada: ${lote.qtDisponivel}',
                style: TextStyle(
                  color: lote.qtDisponivel > 0
                      ? Colors.grey.shade700
                      : Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vendas: ${formatarPeriodoVenda(lote.dataInicioVenda, lote.dataFimVenda)}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (lote.descricaoSetor.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  lote.descricaoSetor.trim(),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _abrirModalidades(opcoes),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    vendaDisponivel
                        ? 'Escolher modalidade'
                        : 'Consultar modalidades',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirModalidades(List<EventoLote> opcoes) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ModalidadesIngressoScreen(
          opcoes: opcoes,
          taxaPercentual: widget.loja.vrtaxaing,
          taxaMinima: widget.loja.vrtaxaminimaingresso,
          nomeModalidade: _nomeModalidade,
          onComprar: (lote, quantidade) =>
              iniciarReserva(lote, quantidadeSelecionada: quantidade),
        ),
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

  Widget _politicaEvento() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PoliticaCompraScreen(tipo: 'INGRESSO'),
              ),
            ),
            icon: const Icon(Icons.policy_outlined),
            label: const Text(
              'Política de compra de ingresso',
              style: TextStyle(fontSize: 15),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(48, 0, 16, 4),
            child: Text(
              'Para cancelamento e alteração de participante, acesse o ingresso em Carteira/Ingressos.',
              style: TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
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
      appBar: ClubbarAppBar(mostrarVoltar: true, onVoltar: widget.onVoltar),
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
                            height: 260,
                            width: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: ev.bannerUrl.trim().isNotEmpty
                                ? Image.network(
                                    ev.bannerUrl,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      size: 48,
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
                            ...atracoesOrdenadas.asMap().entries.map(
                              (entrada) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    onTap: () =>
                                        _abrirDetalhesAtracao(entrada.value),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.blue.shade600,
                                          width: 1.4,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.schedule_rounded,
                                                size: 19,
                                                color: Colors.blue.shade700,
                                              ),
                                              const SizedBox(width: 7),
                                              Expanded(
                                                child: Text(
                                                  _duracaoPrevista(
                                                    entrada.value,
                                                  ),
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              Icon(
                                                Icons.chevron_right_rounded,
                                                color: Colors.blue.shade700,
                                                size: 26,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _numeroAtracao(entrada.key),
                                              const SizedBox(width: 10),
                                              _fotoAtracao(entrada.value),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      entrada.value.nome,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                    if (entrada
                                                        .value
                                                        .estilos
                                                        .isNotEmpty) ...[
                                                      const SizedBox(height: 7),
                                                      _badgesEstilos(
                                                        entrada.value,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),
                          Row(
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
                                label: const Text('Atualizar lotes'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          if (lotes.isEmpty)
                            estadoVazioLotes()
                          else
                            ..._lotesGlobaisAgrupados.map(cardLoteGlobal),
                          const SizedBox(height: 24),
                          if (ev.descricao.trim().isNotEmpty &&
                              ev.descricao.trim().toLowerCase() != 'null') ...[
                            const SizedBox(height: 8),
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
                          _politicaEvento(),
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
