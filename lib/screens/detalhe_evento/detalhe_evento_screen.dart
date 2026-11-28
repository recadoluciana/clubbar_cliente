import 'dart:async';

import '../../widgets/explicacao_taxas_ingresso.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/evento_detalhe.dart';
import '../../models/evento_lote.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/cart_badge_notifier.dart';
import '../../services/carteira_badge_notifier.dart';
import '../../services/main_navigation_controller.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/clubbar_page_header.dart';
import '../../widgets/prazo_expirado_dialog.dart';

import 'package:share_plus/share_plus.dart';

import '../../config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../utils/value_formatters.dart';
import '../../utils/taxa_ingresso.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/login_redirect.dart';
import '../../utils/horario_brasil.dart';
import '../../utils/cpf_utils.dart';
import '../pagamento/pagamento_sucesso_screen.dart';
import '../produtos_loja/produtos_loja_screen.dart';
import 'participantes_reserva_screen.dart';
import '../pagamento/politica_compra_screen.dart';
import 'meia_entrada_screen.dart';

const int _limiteIngressosPorTransacao = 5;
const String _mensagemLimiteIngressosPorTransacao =
    'Máximo de 5 ingressos por compra. Caso necessite de mais ingressos realize duas ou mais compras.';

bool _ehCortesia(EventoLote lote) =>
    lote.tipoIngresso.trim().toUpperCase() == 'CORTESIA' || lote.preco <= 0;

bool _ehModalidadeMeiaEntrada(EventoLote lote) =>
    lote.aplicaCotaLegal ||
    lote.tipoIngresso.trim().toUpperCase() == 'MEIA_IDOSO';

int _limitePorTransacao(EventoLote lote) =>
    _ehCortesia(lote) ? 2 : _limiteIngressosPorTransacao;

String _mensagemLimitePorTransacao(EventoLote lote) => _ehCortesia(lote)
    ? 'Cortesia limitada a 1 ingresso por CPF neste evento.'
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
  State<DetalheEventoScreen> createState() => _NavegacaoEventoState();
}

class _ObservadorNavegacaoEvento extends NavigatorObserver {
  bool _ativo = true;

  void encerrar() {
    _ativo = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MainNavigationController.ocultarBarra.value = false;
    });
  }

  void _atualizar(Route<dynamic>? rota) {
    final ocultar = rota?.settings.name == 'conferir-sacola' ||
        rota?.settings.name == 'setor-ingressos';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ativo) MainNavigationController.ocultarBarra.value = ocultar;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _atualizar(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _atualizar(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _atualizar(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _atualizar(newRoute);
  }
}

class _NavegacaoEventoState extends State<DetalheEventoScreen> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _detalheKey = GlobalKey<_DetalheEventoScreenState>();
  final _observador = _ObservadorNavegacaoEvento();

  @override
  void dispose() {
    _observador.encerrar();
    super.dispose();
  }

  void _voltar() {
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      unawaited(navigator.maybePop());
    } else {
      final detalhe = _detalheKey.currentState;
      if (detalhe != null) {
        unawaited(detalhe._confirmarSaida());
      } else {
        _sairDoEvento();
      }
    }
  }

  void _sairDoEvento() =>
      (widget.onVoltar ?? MainNavigationController.fecharTelaInterna)();

  @override
  Widget build(BuildContext context) {
    // O fluxo do evento até o pagamento compartilha a navegação principal.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _voltar();
      },
      child: Navigator(
        key: _navigatorKey,
        observers: [_observador],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'detalhe-evento'),
          builder: (_) => _DetalheEventoConteudo(
            key: _detalheKey,
            eventoId: widget.eventoId,
            loja: widget.loja,
            onVoltar: _sairDoEvento,
          ),
        ),
      ),
    );
  }
}

class _DetalheEventoConteudo extends StatefulWidget {
  final int eventoId;
  final Loja loja;
  final VoidCallback onVoltar;

  const _DetalheEventoConteudo({
    super.key,
    required this.eventoId,
    required this.loja,
    required this.onVoltar,
  });

  @override
  State<_DetalheEventoConteudo> createState() => _DetalheEventoScreenState();
}

class _TelaSelecaoIngressos extends StatefulWidget {
  final List<EventoLote> Function() lotes;
  final bool somenteCortesia;
  final String nomeEvento;
  final String dataEvento;
  final String imagemEvento;
  final int Function() segundosReserva;
  final void Function(BuildContext) verificarExpiracao;
  final int Function() totalSelecionado;
  final Future<void> Function() onComprar;
  final Future<void> Function() onAtualizar;
  final Widget Function(List<EventoLote>, VoidCallback, bool) construirSetor;
  final Widget Function(List<EventoLote>, VoidCallback, bool) construirModalidades;

  const _TelaSelecaoIngressos({
    required this.lotes, required this.somenteCortesia, required this.nomeEvento, required this.dataEvento,
    required this.imagemEvento, required this.segundosReserva,
    required this.verificarExpiracao, required this.totalSelecionado,
    required this.onComprar, required this.onAtualizar, required this.construirSetor,
    required this.construirModalidades,
  });

  @override
  State<_TelaSelecaoIngressos> createState() => _TelaSelecaoIngressosState();
}

class _TelaSelecaoIngressosState extends State<_TelaSelecaoIngressos> {
  Set<int>? _idsSelecionados;
  Timer? _timer;
  bool _comprando = false;
  late bool _somenteCortesia;

  @override
  void initState() {
    super.initState();
    _somenteCortesia = widget.somenteCortesia;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (widget.segundosReserva() <= 0 && ModalRoute.of(context)?.isCurrent == true) {
        widget.verificarExpiracao(context);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lotes = widget.lotes().where((lote) => _ehCortesia(lote) == _somenteCortesia).toList();
    final nomesSetores = lotes.map((lote) => lote.nomeSetor.trim().toLowerCase()).toSet();
    final setorUnico = nomesSetores.length == 1;
    final mostrandoModalidades = setorUnico || _idsSelecionados != null;
    final opcoes = setorUnico
        ? lotes
        : lotes.where((lote) => _idsSelecionados?.contains(lote.lotePrecoId) == true).toList();
    void voltar() {
      if (_somenteCortesia && !widget.somenteCortesia) {
        setState(() { _somenteCortesia = false; _idsSelecionados = null; });
      } else if (!setorUnico && _idsSelecionados != null) {
        setState(() => _idsSelecionados = null);
      } else {
        Navigator.of(context).pop();
      }
    }

    return PopScope(
      canPop: !(_somenteCortesia && !widget.somenteCortesia) && (setorUnico || _idsSelecionados == null),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) voltar();
      },
      child: mostrandoModalidades && opcoes.isNotEmpty
          ? widget.construirModalidades(opcoes, voltar, setorUnico)
          : _listaDeSetores(context, lotes),
    );
  }

  Widget _listaDeSetores(BuildContext context, List<EventoLote> lotes) {
    final porLote = <int, List<EventoLote>>{};
    for (final lote in lotes) {
      porLote.putIfAbsent(lote.loteGlobalId == 0 ? lote.loteId : lote.loteGlobalId, () => []).add(lote);
    }
    final segundos = widget.segundosReserva();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: ClubbarAppBar(
        titulo: _somenteCortesia ? 'Resgatar cortesia' : 'Comprar ingressos', iconeTitulo: Icons.confirmation_number_rounded,
        corIconeTitulo: Colors.blue, tituloAlinhadoEsquerda: true,
        mostrarVoltar: true, mostrarSessao: false,
        actions: [
          if (segundos > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_outlined, color: Colors.red, size: 18),
                const SizedBox(width: 4),
                Text('${(segundos ~/ 60).toString().padLeft(2, '0')}:${(segundos % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
            ),
        ],
      ),
      bottomNavigationBar: _somenteCortesia ? null : DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF9E6), Color(0xFFFFE7A3)],
          ),
        ),
        child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _comprando || widget.totalSelecionado() == 0 ? null : () async {
              setState(() => _comprando = true);
              try { await widget.onComprar(); }
              finally { if (mounted) setState(() => _comprando = false); }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: Text('Comprar ingressos (${widget.totalSelecionado()})'),
          ),
        ),
        ),
      ),
      body: Column(children: [
        ClubbarPageHeader(
          titulo: widget.nomeEvento, subtitulo: widget.dataEvento,
          icone: Icons.confirmation_number_rounded, imagemAvatarUrl: widget.imagemEvento,
          tamanhoAvatar: 56, larguraAvatar: 86, avatarRetangular: true,
          corTitulo: Colors.black87, maxLinhasTitulo: 2,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (lotes.isEmpty)
                const Text('Não há ingressos disponíveis no momento.')
              else ...[
                Row(children: [
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selecione um setor', style: TextStyle(color: Colors.black)),
                      SizedBox(height: 4),
                      Text('Máximo de 5 ingressos por compra, considerando todos os setores.',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  )),
                  TextButton.icon(
                    onPressed: () async { await widget.onAtualizar(); if (mounted) setState(() {}); },
                    icon: const Icon(Icons.refresh, size: 18), label: const Text('Atualizar'),
                  ),
                ]),
                if (!_somenteCortesia && widget.lotes().any((lote) => _ehCortesia(lote) && lote.podeComprarEm(HorarioBrasil.agora()))) ...[
                  Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                    onPressed: () => setState(() { _somenteCortesia = true; _idsSelecionados = null; }),
                    icon: const Icon(Icons.card_giftcard_outlined),
                    label: const Text('Resgatar cortesia'),
                    style: TextButton.styleFrom(foregroundColor: Colors.green.shade700),
                  )),
                ],
                const SizedBox(height: 8),
                for (final opcoesLote in porLote.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(opcoesLote.first.nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  ..._setores(opcoesLote).map((opcoes) => widget.construirSetor(
                    _somenteCortesia ? opcoes : widget.lotes().where((item) =>
                      (item.loteGlobalId == 0 ? item.loteId : item.loteGlobalId) ==
                        (opcoes.first.loteGlobalId == 0 ? opcoes.first.loteId : opcoes.first.loteGlobalId) &&
                      item.nomeSetor.trim().toLowerCase() == opcoes.first.nomeSetor.trim().toLowerCase()).toList(),
                    () => setState(() => _idsSelecionados = opcoes.map((item) => item.lotePrecoId).toSet()),
                    _somenteCortesia,
                  )),
                ],
              ],
            ],
          ),
        ),
      ]),
    );
  }

  List<List<EventoLote>> _setores(List<EventoLote> lotes) {
    final setores = <String, List<EventoLote>>{};
    for (final lote in lotes) {
      setores.putIfAbsent(lote.nomeSetor.trim().toLowerCase(), () => []).add(lote);
    }
    return setores.values.toList();
  }
}

class _ModalidadesIngressoScreen extends StatefulWidget {
  final List<EventoLote> opcoes;
  final bool somenteCortesia;
  final String nomeEvento;
  final String dataHoraEvento;
  final String imagemEventoUrl;
  final double taxaPercentual;
  final double taxaMinima;
  final String Function(EventoLote) nomeModalidade;
  final Future<void> Function(EventoLote lote, int quantidade) onComprar;
  final int Function(int lotePrecoId) quantidadeSelecionada;
  final int Function(int lotePrecoId) quantidadePendente;
  final int Function() totalSelecionado;
  final Future<void> Function(EventoLote lote, int quantidade) onSelecionar;
  final Future<void> Function() onComprarSelecionados;
  final VoidCallback onEntenderTaxa;
  final Map<String, dynamic>? compraEvento;
  final int Function() segundosReserva;
  final void Function(BuildContext) verificarExpiracao;
  final Future<void> Function() onAtualizar;
  final bool setorUnico;
  final VoidCallback? onVoltar;

  const _ModalidadesIngressoScreen({
    required this.opcoes,
    required this.somenteCortesia,
    required this.nomeEvento,
    required this.dataHoraEvento,
    required this.imagemEventoUrl,
    required this.taxaPercentual,
    required this.taxaMinima,
    required this.nomeModalidade,
    required this.onComprar,
    required this.quantidadeSelecionada,
    required this.quantidadePendente,
    required this.totalSelecionado,
    required this.onSelecionar,
    required this.onComprarSelecionados,
    required this.onEntenderTaxa,
    this.compraEvento,
    required this.segundosReserva,
    required this.verificarExpiracao,
    required this.onAtualizar,
    required this.setorUnico,
    this.onVoltar,
  });

  @override
  State<_ModalidadesIngressoScreen> createState() =>
      _ModalidadesIngressoScreenState();
}

class _ModalidadesIngressoScreenState
    extends State<_ModalidadesIngressoScreen> {
  bool _processando = false;
  int _itensNaSacola = 0;
  double _totalSacola = 0;
  final List<String> _detalhesSacola = [];
  bool _sacolaExpandida = false;
  Timer? _timerTopbar;

  @override
  void initState() {
    super.initState();
    _timerTopbar = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
        if (widget.segundosReserva() <= 0 && ModalRoute.of(context)?.isCurrent == true) {
          widget.verificarExpiracao(context);
        }
      }
    });
    final compra = widget.compraEvento;
    _itensNaSacola = int.tryParse('${compra?['quantidade'] ?? 0}') ?? 0;
    _totalSacola = double.tryParse('${compra?['valor_total'] ?? 0}') ?? 0;
    final itens = compra?['itens'];
    if (itens is List) {
      _detalhesSacola.addAll(
        itens.whereType<Map>().map(
          (item) =>
              '${item['quantidade'] ?? 1} x ${item['nome_modalidade'] ?? 'Ingresso'} · ${item['nome_setor'] ?? 'Setor'}',
        ),
      );
    }
  }

  @override
  void dispose() {
    _timerTopbar?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final segundosReserva = widget.segundosReserva();
    final lote = widget.opcoes.first;
    final nomeSetor = lote.nomeSetor.trim();
    final descricaoSetor = lote.descricaoSetor.trim();
    final descricaoPadrao =
        descricaoSetor.toLowerCase() ==
        'setor ${nomeSetor.toLowerCase()} do evento';
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: ClubbarAppBar(
        titulo: widget.somenteCortesia ? 'Resgatar cortesia' : 'Comprar ingressos',
        iconeTitulo: Icons.confirmation_number_rounded,
        corIconeTitulo: Colors.blue,
        tituloAlinhadoEsquerda: true,
        mostrarVoltar: true,
        mostrarSessao: false,
        onVoltar: widget.onVoltar,
        actions: [
          if (segundosReserva > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.red, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${(segundosReserva ~/ 60).toString().padLeft(2, '0')}:${(segundosReserva % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: widget.somenteCortesia ? null : DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF9E6), Color(0xFFFFE7A3)],
          ),
        ),
        child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _processando || widget.totalSelecionado() == 0
                ? null
                : () async {
                    setState(() => _processando = true);
                    try {
                      await widget.onComprarSelecionados();
                    } finally {
                      if (mounted) setState(() => _processando = false);
                    }
                  },
            style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: Text('Comprar ingressos (${widget.totalSelecionado()})'),
          ),
        ),
        ),
      ),
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: widget.nomeEvento.trim().isEmpty
                ? 'Escolha a modalidade'
                : widget.nomeEvento,
            subtitulo: widget.dataHoraEvento,
            subtituloWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.dataHoraEvento == 'Data não informada'
                      ? widget.dataHoraEvento
                      : 'Data: ${widget.dataHoraEvento}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (nomeSetor.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.stadium_outlined,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Setor: $nomeSetor',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
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
                Row(children: [
                  Expanded(child: Text(
                    widget.somenteCortesia ? 'Informe os dados do participante para resgatar.' : 'Máximo de 5 ingressos por compra, considerando todos os setores.',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  )),
                  TextButton.icon(
                    onPressed: () async { await widget.onAtualizar(); if (mounted) setState(() {}); },
                    icon: const Icon(Icons.refresh, size: 18), label: const Text('Atualizar'),
                  ),
                ]),
                if (descricaoSetor.isNotEmpty && !descricaoPadrao) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4CC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8C96A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.auto_awesome_outlined,
                          size: 19,
                          color: Color(0xFF8A6500),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            descricaoSetor,
                            style: const TextStyle(
                              color: Color(0xFF5F4900),
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                for (var i = 0; i < widget.opcoes.length; i++) ...[
                  if (widget.opcoes.map((opcao) => opcao.loteGlobalId == 0 ? opcao.loteId : opcao.loteGlobalId).toSet().length > 1 &&
                      (i == 0 || (widget.opcoes[i].loteGlobalId == 0 ? widget.opcoes[i].loteId : widget.opcoes[i].loteGlobalId) !=
                          (widget.opcoes[i - 1].loteGlobalId == 0 ? widget.opcoes[i - 1].loteId : widget.opcoes[i - 1].loteGlobalId)))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Text(widget.opcoes[i].nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  _cardModalidade(widget.opcoes[i], vendaDisponivel: widget.opcoes[i].podeComprarEm(HorarioBrasil.agora())),
                ],
                if (!widget.somenteCortesia) Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.onEntenderTaxa,
                    icon: const Icon(Icons.info_outline, size: 17),
                    label: const Text('Entenda nossas taxas'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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

  Widget _rodapeModalidades() {
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.primaryContainer,
        elevation: 8,
        child: InkWell(
          onTap: () => setState(() => _sacolaExpandida = !_sacolaExpandida),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_itensNaSacola ${_itensNaSacola == 1 ? 'item' : 'itens'} na sacola · ${ValueFormatters.moeda(_totalSacola)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Icon(
                      _sacolaExpandida ? Icons.expand_more : Icons.expand_less,
                    ),
                  ],
                ),
                if (_sacolaExpandida) ...[
                  const Divider(height: 12),
                  for (final detalhe in _detalhesSacola)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          detalhe,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 132,
                      height: 36,
                      child: FilledButton(
                        onPressed: _itensNaSacola == 0
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Continuar'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _informacoesMeiaEntrada({
    required bool mostrarQuemTemDireito,
    required bool exigeComprovante,
  }) {
    if (!mostrarQuemTemDireito && !exigeComprovante) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (exigeComprovante)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 17,
                  color: Colors.black54,
                ),
                SizedBox(width: 4),
                Text(
                  'Comprovante obrigatório',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          if (exigeComprovante && mostrarQuemTemDireito) const Spacer(),
          if (mostrarQuemTemDireito)
            TextButton.icon(
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const MeiaEntradaScreen()),
              ),
              icon: const Icon(Icons.workspace_premium_outlined, size: 17),
              label: const Text('Quem tem direito'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardModalidade(EventoLote lote, {required bool vendaDisponivel}) {
    final quantidade = widget.quantidadeSelecionada(lote.lotePrecoId);
    final ehCortesia = _ehCortesia(lote);
    final ehMeiaEntrada = _ehModalidadeMeiaEntrada(lote);
    final disponivelModalidade = lote.qtDisponivelParaCompra;
    final modalidadeDisponivel = disponivelModalidade > 0;
    final situacao = lote.situacaoVendaEm(HorarioBrasil.agora());
    final textoSituacao = situacao == 'Disponível' && !vendaDisponivel
        ? 'Indisponível'
        : situacao;
    final corSituacao = textoSituacao == 'Disponível'
        ? Colors.green.shade700
        : textoSituacao == 'Esgotado' || textoSituacao == 'Vendas encerradas'
        ? Colors.red.shade700
        : Colors.grey.shade700;
    final podeDiminuir = quantidade > 0;
    final podeAumentar =
        vendaDisponivel && modalidadeDisponivel &&
        quantidade < _limitePorTransacao(lote) &&
        widget.quantidadePendente(lote.lotePrecoId) < disponivelModalidade;
    final taxaUnitaria = calcularTaxaIngresso(
      lote.preco,
      widget.taxaPercentual,
      widget.taxaMinima,
    );
    final totalPagar = (lote.preco + taxaUnitaria) * quantidade;

    final botaoAdicionar = FilledButton.icon(
      onPressed: !vendaDisponivel || _processando || !modalidadeDisponivel
          ? null
          : () async {
              setState(() => _processando = true);
              try {
                await widget.onComprar(lote, quantidade);
                if (mounted) {
                  setState(() {});
                }
              } finally {
                if (mounted) setState(() => _processando = false);
              }
            },
      icon: Icon(
        ehCortesia ? Icons.card_giftcard_outlined : Icons.add,
        size: 17,
      ),
      label: Text(ehCortesia ? 'Resgatar' : 'Adicionar'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: ehCortesia
            ? Colors.green.shade700
            : const Color(0xFFFFC107),
        foregroundColor: ehCortesia ? Colors.white : Colors.black,
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey.shade600,
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: widget.setorUnico ? 2 : 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(widget.setorUnico ? 20 : 12),
        side: widget.setorUnico ? BorderSide.none : const BorderSide(color: Color(0xFFFFE082)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.nomeModalidade(lote),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            _informacoesMeiaEntrada(
              mostrarQuemTemDireito: ehMeiaEntrada,
              exigeComprovante: lote.exigeComprovante,
            ),
            if (ehCortesia && !modalidadeDisponivel)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Text('Cortesias esgotadas', style: TextStyle(
                    color: Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
            if (ehCortesia && lote.horarioLimiteEntrada != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Válido para entrada até as ${lote.horarioLimiteEntrada} horas.',
                  style: TextStyle(fontSize: 13, color: Colors.deepOrange.shade700, fontWeight: FontWeight.w900)),
              ),
            if (!ehCortesia) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(color: Colors.black),
                          children: [
                            TextSpan(
                              text: ValueFormatters.moeda(lote.preco),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' (+${ValueFormatters.moeda(taxaUnitaria)})',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _controleQuantidade(
                    lote: lote,
                    quantidade: quantidade,
                    podeDiminuir: podeDiminuir,
                    podeAumentar: podeAumentar,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: FittedBox(
                      alignment: Alignment.centerRight,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        ValueFormatters.moeda(totalPagar),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (ehCortesia)
                        const Text(
                          'Limite de 1 ingresso por CPF',
                          style: TextStyle(fontSize: 11, color: Colors.black),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: corSituacao.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          textoSituacao,
                          style: TextStyle(
                            fontSize: 11,
                            color: corSituacao,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (textoSituacao == 'Disponível')
                        Text(
                          '$disponivelModalidade ${disponivelModalidade == 1 ? 'ingresso restante' : 'ingressos restantes'}',
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (ehCortesia) botaoAdicionar,
              ],
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
                : () async {
                    await widget.onSelecionar(lote, quantidade - 1);
                    if (mounted) setState(() {});
                  },
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
                    widget.onSelecionar(lote, quantidade + 1).then((_) {
                      if (mounted) setState(() {});
                    });
                  },
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _DetalheEventoScreenState extends State<_DetalheEventoConteudo> {
  final apiService = ApiService();
  final authStorage = AuthStorage();
  final Map<int, Map<String, dynamic>> _statusLotes = {};

  bool carregando = true;
  bool atualizandoLotes = false;
  bool processandoCompra = false;
  String? erro;

  EventoDetalhe? evento;
  List<EventoLote> lotes = [];
  final Map<int, int> _quantidadesModalidades = {};
  Map<String, dynamic>? _compraEvento;
  final Map<String, Map<String, dynamic>> _participantesDaSacola = {};
  bool _sacolaExpandida = false;
  bool _removendoItemSacola = false;
  bool _confirmandoSaida = false;
  Timer? _timerReservaSacola;
  DateTime? _prazoReservaSacola;
  int _segundosReservaSacola = 0;
  bool _verificandoExpiracaoSelecao = false;
  DateTime? _proximaVerificacaoExpiracao;

  @override
  void initState() {
    super.initState();
    CartBadgeNotifier.atualizarItensDaLojaSelecionada(0);
    CarteiraBadgeNotifier.atualizarItensDaLojaSelecionada(0);
    _carregarQuantidadesDaLoja();
    CarteiraBadgeNotifier.refresh.addListener(_carregarQuantidadesDaLoja);
    carregarDados();
  }

  @override
  void dispose() {
    _timerReservaSacola?.cancel();
    unawaited(_cancelarReservaAoSair());
    CarteiraBadgeNotifier.refresh.removeListener(_carregarQuantidadesDaLoja);
    super.dispose();
  }

  Future<bool> _cancelarReservaAoSair({bool silencioso = true}) async {
    final compra = _compraEvento;
    if (compra == null) return true;
    final itens = compra['itens'];
    final primeiro = itens is List && itens.isNotEmpty && itens.first is Map
        ? itens.first as Map : null;
    final reservaId = int.tryParse('${primeiro?['reserva_ingresso_id'] ?? compra['reserva_ingresso_id']}');
    final clienteId = await authStorage.obterClienteId();
    if (reservaId == null || clienteId == null) {
      if (!silencioso && mounted) AppSnackBar.erro(context, 'Não foi possível identificar a reserva. Tente novamente.');
      return false;
    }
    try {
      await apiService.cancelarReservaIngresso(reservaId: reservaId, clienteId: clienteId);
      return true;
    } catch (e) {
      if (!silencioso && mounted) AppSnackBar.erro(context, apiService.mensagemErroAmigavel(e));
      return false;
    }
  }

  Future<void> _confirmarSaida() async {
    if (_confirmandoSaida || processandoCompra || _removendoItemSacola) return;
    if (_compraEvento == null && _totalSelecionado == 0) {
      widget.onVoltar();
      return;
    }
    _confirmandoSaida = true;
    try {
      final sair = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Deseja sair desta tela?'),
          content: const Text('A sua compra será cancelada.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Continuar compra')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sair e cancelar')),
          ],
        ),
      );
      if (sair != true || !mounted) return;
      final cancelada = await _cancelarReservaAoSair(silencioso: false);
      if (!mounted || !cancelada) return;
      _timerReservaSacola?.cancel();
      _compraEvento = null;
      _quantidadesModalidades.clear();
      _participantesDaSacola.clear();
      widget.onVoltar();
    } finally {
      _confirmandoSaida = false;
    }
  }

  void _iniciarTimerReservaSacola(Map<String, dynamic> compra) {
    final segundos = int.tryParse('${compra['segundos_restantes']}');
    if (segundos == null) return;
    _definirPrazoSacola(HorarioBrasil.agora().add(Duration(seconds: segundos)));
  }

  void _definirPrazoSacola(DateTime prazo) {
    _timerReservaSacola?.cancel();
    _prazoReservaSacola = prazo;
    _segundosReservaSacola = _tempoRestanteSacola();
    if (mounted) setState(() {});
    _timerReservaSacola = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _segundosReservaSacola = _tempoRestanteSacola());
      if (_segundosReservaSacola == 0 && ModalRoute.of(context)?.isCurrent == true) {
        unawaited(_verificarExpiracaoNaSelecao(context));
      }
    });
  }

  Future<void> _verificarExpiracaoNaSelecao(BuildContext tela) async {
    final compra = _compraEvento;
    if (compra == null || _segundosReservaSacola > 0 || _verificandoExpiracaoSelecao ||
        (ModalRoute.of(tela)?.isCurrent != true) ||
        (_proximaVerificacaoExpiracao != null && DateTime.now().isBefore(_proximaVerificacaoExpiracao!))) return;
    final reservaId = int.tryParse('${compra['reserva_ingresso_id']}');
    if (reservaId == null) return;
    _verificandoExpiracaoSelecao = true;
    try {
      final clienteId = await authStorage.obterClienteId();
      if (clienteId == null) throw StateError('Cliente não identificado');
      final atual = await apiService.consultarReserva(reservaId: reservaId, clienteId: clienteId);
      if (!mounted || !tela.mounted || ModalRoute.of(tela)?.isCurrent != true ||
          _compraEvento?['compra_evento_id'] != compra['compra_evento_id']) return;
      final situacao = '${atual['status'] ?? ''}'.toUpperCase();
      final pagamento = '${atual['status_pagamento'] ?? ''}'.toUpperCase();
      final segundos = int.tryParse('${atual['segundos_restantes']}');
      if (pagamento == 'PAGO') {
        _timerReservaSacola?.cancel();
        setState(() { _compraEvento = null; _quantidadesModalidades.clear(); });
        AppSnackBar.sucesso(tela, 'Pagamento confirmado. Confira seus ingressos na carteira.');
        return;
      }
      if (segundos != null && segundos > 0 && !{'EXPIRADA', 'CANCELADA'}.contains(situacao)) {
        _proximaVerificacaoExpiracao = null;
        _definirPrazoSacola(HorarioBrasil.agora().add(Duration(seconds: segundos)));
        return;
      }
      if (segundos == null && !{'EXPIRADA', 'CANCELADA'}.contains(situacao)) {
        throw StateError('Prazo indisponível');
      }
      _timerReservaSacola?.cancel();
      setState(() {
        _compraEvento = null;
        _quantidadesModalidades.clear();
        _participantesDaSacola.clear();
        _segundosReservaSacola = 0;
      });
      await mostrarPrazoExpirado(tela, tipo: PrazoExpiradoTipo.reserva);
      if (mounted) unawaited(atualizarLotes(mostrarConfirmacao: false));
    } catch (_) {
      if (mounted && tela.mounted) {
        _proximaVerificacaoExpiracao = DateTime.now().add(const Duration(seconds: 10));
        AppSnackBar.aviso(tela, 'Não foi possível verificar a reserva. Confira sua conexão e tente novamente.');
      }
    } finally {
      _verificandoExpiracaoSelecao = false;
    }
  }

  int _tempoRestanteSacola() {
    final prazo = _prazoReservaSacola;
    if (prazo == null) return 0;
    return HorarioBrasil.segundosRestantes(
      prazo.difference(HorarioBrasil.agora()),
    ).clamp(0, 86400);
  }

  Future<void> _carregarQuantidadesDaLoja() async {
    final clienteId = await authStorage.obterClienteId();
    if (clienteId == null || clienteId == 0 || !mounted) return;
    try {
      final carrinho = await apiService.buscarCarrinho(
        clienteId: clienteId,
        organizacaoId: widget.loja.organizacaoId,
        lojaId: widget.loja.id,
      );
      final itens = carrinho['itens'];
      final total = itens is List
          ? itens.fold<int>(
              0,
              (soma, item) => soma + (int.tryParse('${item['qt']}') ?? 1),
            )
          : 0;
      if (mounted) CartBadgeNotifier.atualizarItensDaLojaSelecionada(total);
    } catch (_) {
      if (mounted) CartBadgeNotifier.atualizarItensDaLojaSelecionada(0);
    }
    try {
      final itens = await apiService.buscarPendentes(
        clienteId: clienteId,
        lojaId: widget.loja.id,
      );
      final total = itens.fold<int>(
        0,
        (soma, item) => soma + (int.tryParse('${item['qtitvenda'] ?? 0}') ?? 0),
      );
      if (mounted) CarteiraBadgeNotifier.atualizarItensDaLojaSelecionada(total);
    } catch (_) {
      if (mounted) CarteiraBadgeNotifier.atualizarItensDaLojaSelecionada(0);
    }
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

  Future<void> atualizarLotes({bool mostrarConfirmacao = true}) async {
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
      if (mounted && mostrarConfirmacao) {
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

  Future<void> compartilharEvento(BuildContext botaoContext) async {
    final ev = evento;
    if (ev == null) return;

    final texto =
        '''
  🎟️ ${ev.titulo}

  📅 ${DateFormatters.dataHoraSimples(ev.dataInicio)}

  📍 ${ev.local}
  🏙️ ${ev.nomeCidade}${ev.sgEstado.trim().isEmpty ? '' : ' - ${ev.sgEstado}'}

  Garanta seu ingresso e o que vai consumir acessando o app Clubbar.

  👉 Acesse:
  ${AppConfig.appWebUrl}/compartilhar/evento/${widget.eventoId}${kIsWeb ? '?v=2' : ''}
  ''';

    final convite = texto.trim();
    if (kIsWeb) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              const Expanded(child: Text('Compartilhar evento')),
              IconButton(
                tooltip: 'Fechar',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          content: const Text('Escolha como deseja enviar o convite.'),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      try {
                        await Clipboard.setData(ClipboardData(text: convite));
                        if (!dialogContext.mounted || !mounted) return;
                        Navigator.pop(dialogContext);
                        AppSnackBar.sucesso(
                          context,
                          'Convite copiado. Agora é só colar onde desejar.',
                        );
                      } catch (_) {
                        if (mounted) {
                          AppSnackBar.erro(
                            context,
                            'Não foi possível copiar o convite.',
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Copiar convite', maxLines: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final uri = Uri.https('wa.me', '/', {'text': convite});
                      try {
                        final abriu = await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                        if (!dialogContext.mounted || !mounted) return;
                        if (abriu) {
                          Navigator.pop(dialogContext);
                        } else {
                          AppSnackBar.erro(
                            context,
                            'Não foi possível abrir o WhatsApp. Você pode copiar o convite.',
                          );
                        }
                      } catch (_) {
                        if (mounted) {
                          AppSnackBar.erro(
                            context,
                            'Não foi possível abrir o WhatsApp. Você pode copiar o convite.',
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.send),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Compartilhar WhatsApp', maxLines: 1),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      return;
    }
    try {
      final caixa = botaoContext.findRenderObject();
      final origem = caixa is RenderBox && caixa.hasSize
          ? caixa.localToGlobal(Offset.zero) & caixa.size
          : null;
      await Share.share(
        convite,
        subject: ev.titulo,
        sharePositionOrigin: origem,
      );
    } catch (_) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          'Não foi possível compartilhar o evento. Tente novamente.',
        );
      }
    }
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
    final fotos = [atracao.bannerUrl, atracao.foto2, atracao.foto3]
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .map(
          (url) => url.startsWith('http')
              ? url
              : '${AppConfig.apiBaseUrl}${url.startsWith('/') ? '' : '/'}$url',
        )
        .toList();
    final perfil = atracao.instagram.trim();
    final instagramUrl = perfil.startsWith('https://')
        ? perfil
        : 'https://www.instagram.com/${perfil.replaceFirst(RegExp(r'^@'), '')}/';
    final telefone = atracao.telefoneContato.replaceAll(RegExp(r'[^0-9+]'), '');
    var fotoAtual = 0;
    final fotoController = PageController();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
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
              if (fotos.isNotEmpty) ...[
                StatefulBuilder(
                  builder: (context, setFotoState) {
                    void irPara(int indice) {
                      final proxima = indice.clamp(0, fotos.length - 1) as int;
                      fotoController.animateToPage(
                        proxima,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                      );
                    }

                    return Column(
                      children: [
                        SizedBox(
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  width: double.infinity,
                                  color: Colors.black,
                                  child: PageView.builder(
                                    controller: fotoController,
                                    itemCount: fotos.length,
                                    onPageChanged: (indice) =>
                                        setFotoState(() => fotoAtual = indice),
                                    itemBuilder: (_, index) => Image.network(
                                      fotos[index],
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (fotos.length > 1)
                                Positioned(
                                  left: 4,
                                  child: IconButton.filled(
                                    onPressed: () => irPara(fotoAtual - 1),
                                    icon: const Icon(Icons.chevron_left),
                                    color: Colors.white,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black54,
                                    ),
                                  ),
                                ),
                              if (fotos.length > 1)
                                Positioned(
                                  right: 4,
                                  child: IconButton.filled(
                                    onPressed: () => irPara(fotoAtual + 1),
                                    icon: const Icon(Icons.chevron_right),
                                    color: Colors.white,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black54,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (fotos.length > 1) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var index = 0; index < fotos.length; index++)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: index == fotoAtual ? 18 : 7,
                                  height: 7,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index == fotoAtual
                                        ? Colors.blue.shade700
                                        : Colors.grey.shade400,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Sobre a atração',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
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
                  ),
                ),
              ],
              if (perfil.isNotEmpty || telefone.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (perfil.isNotEmpty)
                      TextButton(
                        onPressed: () => _abrirLinkAtracao(instagramUrl),
                        child: Text(perfil),
                      ),
                    if (telefone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          'Contratar show: ${atracao.telefoneContato}',
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirLinkAtracao(String valor) async {
    final uri = Uri.tryParse(valor.trim());
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) AppSnackBar.erro(context, 'Não foi possível abrir o link.');
    }
  }

  Future<int?> _obterClienteIdLogado() async {
    final clienteId = await authStorage.obterClienteId();
    if (!mounted) return null;

    if (clienteId == null || clienteId == 0) {
      await direcionarParaLogin(
        Navigator.of(context, rootNavigator: true).context,
      );
      return null;
    }

    return clienteId;
  }

  Future<void> _resgatarCortesia(EventoLote lote) async {
    if (processandoCompra || !mounted) return;
    final clienteId = await _obterClienteIdLogado();
    if (clienteId == null || !mounted) return;
    var nome = '';
    var cpf = '';
    var enviando = false;
    String? erro;
    final resgatada = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, atualizarDialogo) => PopScope(
          canPop: !enviando,
          child: AlertDialog(
            title: const Text('Resgatar cortesia'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Informe os dados do participante. Cada CPF pode resgatar uma cortesia neste evento.'),
                  const SizedBox(height: 16),
                  TextField(onChanged: (valor) => nome = valor, textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nome completo')),
                  const SizedBox(height: 12),
                  TextField(onChanged: (valor) => cpf = valor, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'CPF')),
                  if (erro != null) ...[
                    const SizedBox(height: 12),
                    Text(erro!, style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: enviando ? null : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar')),
              FilledButton(
                onPressed: enviando ? null : () async {
                  final nomeInformado = nome.trim();
                  final cpfInformado = CpfUtils.somenteNumeros(cpf);
                  if (nomeInformado.length < 3 || !CpfUtils.validar(cpfInformado)) {
                    atualizarDialogo(() => erro = 'Confira o nome e o CPF do participante.');
                    return;
                  }
                  atualizarDialogo(() { enviando = true; erro = null; });
                  try {
                    final resposta = await apiService.resgatarCortesiaDireta(
                      clienteId: clienteId, loteId: lote.loteId,
                      lotePrecoId: lote.lotePrecoId, nome: nomeInformado, cpf: cpfInformado,
                    );
                    if (resposta['gratuito'] != true && resposta['venda_id'] == null) {
                      throw Exception('Não foi possível confirmar o resgate.');
                    }
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                  } catch (e) {
                    if (dialogContext.mounted) atualizarDialogo(() {
                      erro = apiService.mensagemErroAmigavel(e);
                      enviando = false;
                    });
                  }
                },
                child: Text(enviando ? 'Resgatando...' : 'Resgatar cortesia'),
              ),
            ],
          ),
        ),
      ),
    );
    if (resgatada != true || !mounted) return;
    CarteiraBadgeNotifier.atualizar();
    await atualizarLotes(mostrarConfirmacao: false);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PagamentoSucessoScreen(
        lojaDestino: widget.loja,
        tituloAppBar: evento?.titulo ?? 'Evento',
        tituloSucesso: 'Resgate realizado com sucesso',
        descricaoSucesso: 'Seu ingresso está disponível na Carteira.',
        oferecerCardapio: true,
      ),
    ));
  }

  Future<void> iniciarReserva(
    EventoLote lote, {
    int? quantidadeSelecionada,
  }) async {
    if (processandoCompra) return;
    if (_ehCortesia(lote)) {
      await _resgatarCortesia(lote);
      return;
    }
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
    if (_ehCortesia(lote)) {
      final compraAtual = _compraEvento;
      final cortesiasNaCompra = compraAtual?['itens'] is List
          ? (compraAtual!['itens'] as List).whereType<Map>().fold<int>(
              0,
              (total, item) =>
                  total +
                  ((double.tryParse('${item['valor_unitario'] ?? 0}') ?? 0) <= 0
                      ? (int.tryParse('${item['quantidade'] ?? 1}') ?? 1)
                      : 0),
            )
          : 0;
      if (cortesiasNaCompra + quantidade > 2) {
        AppSnackBar.aviso(
          context,
          'Você pode adicionar no máximo 2 cortesias por transação.',
        );
        return;
      }
    }
    setState(() => processandoCompra = true);
    try {
      final clienteId = await _obterClienteIdLogado();
      if (clienteId == null) return;
      final item = {
        'lote_id': lote.loteId,
        'lotepreco_id': lote.lotePrecoId,
        'quantidade': quantidade,
      };
      final compraAtual = _compraEvento;
      final compra = compraAtual == null
          ? await apiService.criarCompraEventoItem(
              clienteId: clienteId,
              item: item,
            )
          : await apiService.adicionarIngressoCompraEvento(
              compraEventoId: int.parse('${compraAtual['compra_evento_id']}'),
              clienteId: clienteId,
              item: item,
            );
      if (!mounted) return;
      final segundosRecebidos = int.tryParse('${compra['segundos_restantes']}');
      final segundosAtuais = _tempoRestanteSacola();
      setState(() => _compraEvento = compra);
      if (compraAtual == null) {
        _iniciarTimerReservaSacola(compra);
      } else if (segundosRecebidos != null && segundosRecebidos < segundosAtuais) {
        _iniciarTimerReservaSacola(compra);
      }
      AppSnackBar.sucesso(context, 'Ingresso adicionado.');
      // A inclusão já reserva o estoque no servidor. Recarrega a mesma fonte
      // usada pelo botão "Atualizar" para refletir imediatamente o saldo.
      await atualizarLotes(mostrarConfirmacao: false);
    } catch (e) {
      if (mounted) {
        if (apiService.erroDeSessao(e)) {
          await authStorage.limparToken();
          if (mounted) {
            await direcionarParaLogin(
              Navigator.of(context, rootNavigator: true).context,
              mensagem: 'Sua sessão terminou. Entre novamente para comprar seu ingresso.',
            );
          }
          return;
        }
        final mensagem = apiService.mensagemErroAmigavel(e);
        if (lote.aplicaCotaLegal &&
            mensagem.toLowerCase().contains('cota legal')) {
          AppSnackBar.erro(
            context,
            'A cota legal de meia-entrada deste setor foi atingida. '
            'Cota do setor: ${lote.cotaLegalSetor} ingresso${lote.cotaLegalSetor == 1 ? '' : 's'}; '
            'disponíveis agora: ${lote.qtDisponivelCotaLegalSetor}.',
          );
        } else {
          AppSnackBar.erro(context, mensagem);
        }
      }
    } finally {
      if (mounted) setState(() => processandoCompra = false);
    }
  }

  int get _totalSelecionado => _quantidadesModalidades.values.fold(0, (soma, valor) => soma + valor);

  List<Map<String, dynamic>> _itensReservadosDaModalidade(int lotePrecoId) {
    final itens = _compraEvento?['itens'];
    if (itens is! List) return [];
    return itens.whereType<Map>()
        .where((item) => int.tryParse('${item['lotepreco_id']}') == lotePrecoId)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int _quantidadeReservada(int lotePrecoId) =>
      _itensReservadosDaModalidade(lotePrecoId).fold(
        0, (soma, item) => soma + (int.tryParse('${item['quantidade'] ?? 1}') ?? 1),
      );

  int _quantidadeExibida(int lotePrecoId) =>
      _quantidadeReservada(lotePrecoId) + (_quantidadesModalidades[lotePrecoId] ?? 0);

  Future<void> _selecionarQuantidade(EventoLote lote, int quantidade) async {
    if (_removendoItemSacola || processandoCompra) return;
    final reservados = _quantidadeReservada(lote.lotePrecoId);
    final anterior = _quantidadeExibida(lote.lotePrecoId);
    final totalReservado = int.tryParse('${_compraEvento?['quantidade'] ?? 0}') ?? 0;
    if (quantidade > anterior && totalReservado + _totalSelecionado >= _limiteIngressosPorTransacao) {
      AppSnackBar.aviso(context, _mensagemLimiteIngressosPorTransacao);
      return;
    }
    if (quantidade < reservados) {
      final itens = _itensReservadosDaModalidade(lote.lotePrecoId);
      if (itens.isNotEmpty) {
        try {
          await _removerItemSacola(itens.last);
          if (mounted) await atualizarLotes(mostrarConfirmacao: false);
        } catch (_) {
          // A exclusão já apresenta a mensagem de erro ao usuário.
        }
      }
      return;
    }
    setState(() {
      final pendentes = quantidade - reservados;
      if (pendentes <= 0) {
        _quantidadesModalidades.remove(lote.lotePrecoId);
      } else {
        _quantidadesModalidades[lote.lotePrecoId] = pendentes;
      }
    });
  }

  Future<void> _comprarSelecionados() async {
    if (processandoCompra) return;
    if (_totalSelecionado == 0) {
      if (_compraEvento != null) await _abrirCompraEvento();
      return;
    }
    final opcoes = lotes.where((lote) => (_quantidadesModalidades[lote.lotePrecoId] ?? 0) > 0).toList();
    if (opcoes.isEmpty || opcoes.length != _quantidadesModalidades.length ||
        opcoes.any((lote) => _ehCortesia(lote) || !lote.podeComprarEm(HorarioBrasil.agora()) ||
          (_quantidadesModalidades[lote.lotePrecoId] ?? 0) > lote.qtDisponivelParaCompra)) {
      AppSnackBar.aviso(context, 'Algum ingresso selecionado não está mais disponível. Confira as quantidades.');
      await atualizarLotes(mostrarConfirmacao: false);
      return;
    }
    final itens = opcoes.map((lote) => {
      'lote_id': lote.loteId,
      'lotepreco_id': lote.lotePrecoId,
      'quantidade': _quantidadesModalidades[lote.lotePrecoId]!,
    }).toList();
    setState(() => processandoCompra = true);
    try {
      final clienteId = await _obterClienteIdLogado();
      if (clienteId == null) return;
      final compraAnterior = _compraEvento;
      final compra = compraAnterior == null
          ? await apiService.criarReservaIngressoGrupo(clienteId: clienteId, itens: itens)
          : await apiService.adicionarGrupoCompraEvento(
              compraEventoId: int.parse('${compraAnterior['compra_evento_id']}'),
              clienteId: clienteId, itens: itens);
      if (!mounted) return;
      setState(() {
        _compraEvento = compra;
        _quantidadesModalidades.clear();
        processandoCompra = false;
      });
      final segundos = int.tryParse('${compra['segundos_restantes']}');
      if (compraAnterior == null || (segundos != null && segundos < _tempoRestanteSacola() - 2)) {
        _iniciarTimerReservaSacola(compra);
      }
      await atualizarLotes(mostrarConfirmacao: false);
      if (mounted) await _abrirCompraEvento();
    } catch (e) {
      if (!mounted) return;
      if (apiService.erroDeSessao(e)) {
        await authStorage.limparToken();
        if (mounted) await direcionarParaLogin(Navigator.of(context, rootNavigator: true).context,
          mensagem: 'Sua sessão terminou. Entre novamente para comprar seu ingresso.');
      } else {
        AppSnackBar.erro(context, apiService.mensagemErroAmigavel(e));
        await atualizarLotes(mostrarConfirmacao: false);
      }
    } finally {
      if (mounted) setState(() => processandoCompra = false);
    }
  }

  List<BeneficioIngresso> _beneficiosDaCompra(Map<String, dynamic> compra) {
    final itens = compra['itens'];
    if (itens is! List) return const [];
    final vistos = <int>{};
    return itens
        .whereType<Map>()
        .expand(
          (item) => (item['beneficios_validos'] is List)
              ? (item['beneficios_validos'] as List).whereType<Map>().map(
                  (beneficio) => BeneficioIngresso.fromJson(
                    Map<String, dynamic>.from(beneficio),
                  ),
                )
              : const <BeneficioIngresso>[],
        )
        .where((beneficio) => beneficio.id > 0 && vistos.add(beneficio.id))
        .toList();
  }

  Future<void> _abrirCompraEvento([
    List<Map<String, dynamic>>? itensAtualizados,
  ]) async {
    final compra = _compraEvento;
    if (compra == null || !mounted) return;
    // A sacola já foi sincronizada após a exclusão. A navegação deve ser
    // imediata; a API valida a validade da reserva ao salvar os participantes.
    final itens = itensAtualizados ??
        (compra['itens'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        <Map<String, dynamic>>[];
    final reserva = {
      ...compra,
      'segundos_restantes': _tempoRestanteSacola(),
      if (itens.isNotEmpty)
        'reserva_ingresso_id': itens.first['reserva_ingresso_id'],
      'itens': itens
          .map((item) => {...item, 'quantidade': 1})
          .toList(),
      'quantidade': itens.length,
    };
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'conferir-sacola'),
        builder: (_) => ParticipantesReservaScreen(
          loja: widget.loja,
          reserva: reserva,
          prazoReserva: _prazoReservaSacola,
          onPrazoAlterado: (prazo) {
            if (_compraEvento?['compra_evento_id'] == compra['compra_evento_id']) {
              _definirPrazoSacola(prazo);
            }
          },
          nomeEvento: evento?.titulo ?? 'Evento',
          dataHoraEvento: DateFormatters.dataCompleta(evento?.dataInicio ?? ''),
          imagemEventoUrl: evento?.bannerUrl ?? '',
          nomeLote: 'Compra do evento',
          nomeSetor: 'Modalidades selecionadas',
          modalidade: 'Compra do evento',
          beneficios: _beneficiosDaCompra(reserva),
          onRemoverIngresso: _removerItemSacola,
          participantesSalvos: _participantesDaSacola,
          onParticipantesAlterados: (participantes) {
            if (_compraEvento?['compra_evento_id'] != compra['compra_evento_id']) return;
            _participantesDaSacola.addAll(participantes);
          },
          onReservaExpirada: () {
            if (_compraEvento?['compra_evento_id'] != compra['compra_evento_id']) return;
            _participantesDaSacola.clear();
            _timerReservaSacola?.cancel();
            if (!mounted) return;
            setState(() {
              _compraEvento = null;
              _quantidadesModalidades.clear();
              _segundosReservaSacola = 0;
            });
            unawaited(atualizarLotes(mostrarConfirmacao: false));
          },
          onReservaConcluida: () {
            _participantesDaSacola.clear();
            _timerReservaSacola?.cancel();
            if (!mounted) return;
            // A compra confirmada não é uma reserva abandonada ao sair.
            setState(() {
              _compraEvento = null;
              _quantidadesModalidades.clear();
              _segundosReservaSacola = 0;
            });
          },
        ),
      ),
    );
    if (mounted) {
      // A confirmação do participante pertence à tela anterior e não deve
      // cobrir o botão de compra ao retornar à seleção.
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      if (_compraEvento != null) {
        setState(() => _segundosReservaSacola = _tempoRestanteSacola());
      }
    }
  }

  Future<void> _removerItemSacola(Map<String, dynamic> item) async {
    final compra = _compraEvento;
    if (compra == null || _removendoItemSacola) {
      throw StateError('Não foi possível excluir o ingresso.');
    }
    final compraId = int.tryParse('${compra['compra_evento_id']}');
    final reservaId = int.tryParse('${item['reserva_ingresso_id']}');
    final clienteId = await authStorage.obterClienteId();
    if (!mounted) throw StateError('Tela não está mais disponível.');
    if (compraId == null || reservaId == null || clienteId == null) {
      AppSnackBar.erro(context, 'Não foi possível identificar o ingresso.');
      throw StateError('Não foi possível identificar o ingresso.');
    }
    setState(() => _removendoItemSacola = true);
    try {
      final resposta = await apiService.removerIngressoCompraEvento(
        compraEventoId: compraId,
        reservaId: reservaId,
        clienteId: clienteId,
      );
      _participantesDaSacola.remove('$reservaId');
      final itensServidor = (resposta['itens'] as List?)
          ?.whereType<Map>()
          // Nunca restaura o ingresso que acabou de ser excluído, mesmo se
          // a resposta de uma versão antiga da API ainda o incluir.
          .where((outro) => '${outro['reserva_ingresso_id']}' != '$reservaId')
          .map((outro) => Map<String, dynamic>.from(outro))
          .toList();
      if (itensServidor != null) {
        _atualizarSacolaComItens(compra, itensServidor);
      } else {
        _removerItemLocalDaSacola(compra, reservaId);
      }
    } catch (e) {
      final mensagem = apiService.mensagemErroAmigavel(e);
      if (mensagem.toLowerCase().contains('item da compra não encontrado')) {
        // O checkout pode ter encerrado a reserva no servidor enquanto a
        // tela ainda mantinha uma cópia antiga da sacola.
        _participantesDaSacola.remove('$reservaId');
        _removerItemLocalDaSacola(compra, reservaId);
      } else if (mounted) {
        AppSnackBar.erro(context, mensagem);
        rethrow;
      }
    } finally {
      if (mounted) setState(() => _removendoItemSacola = false);
    }
  }

  void _removerItemLocalDaSacola(Map<String, dynamic> compra, int reservaId) {
    final itens =
        (compra['itens'] as List?)
            ?.whereType<Map>()
            .where((outro) => '${outro['reserva_ingresso_id']}' != '$reservaId')
            .map((outro) => Map<String, dynamic>.from(outro))
            .toList() ??
        <Map<String, dynamic>>[];
    final quantidadeAtual = itens.fold<int>(
      0,
      (total, outro) =>
          total + (int.tryParse('${outro['quantidade'] ?? 1}') ?? 1),
    );
    final valorAtual = itens.fold<double>(
      0,
      (total, outro) =>
          total +
          (double.tryParse(
                '${outro['valor_total'] ?? outro['subtotal'] ?? 0}',
              ) ??
              0),
    );
    if (!mounted) return;
    setState(() {
      if (itens.isEmpty) {
        _sacolaExpandida = false;
        _timerReservaSacola?.cancel();
        _timerReservaSacola = null;
        _segundosReservaSacola = 0;
      }
      _compraEvento = itens.isEmpty
          ? null
          : {
              ...compra,
              'itens': itens,
              'quantidade': quantidadeAtual,
              'valor_total': valorAtual,
            };
    });
  }

  void _atualizarSacolaComItens(
    Map<String, dynamic> compra,
    List<Map<String, dynamic>> itens,
  ) {
    final quantidade = itens.fold<int>(
      0,
      (total, item) =>
          total + (int.tryParse('${item['quantidade'] ?? 1}') ?? 1),
    );
    final valor = itens.fold<double>(
      0,
      (total, item) =>
          total +
          (double.tryParse('${item['valor_total'] ?? item['subtotal'] ?? 0}') ??
              0),
    );
    if (!mounted) return;
    setState(() {
      _compraEvento = itens.isEmpty
          ? null
          : {
              ...compra,
              'itens': itens,
              'quantidade': quantidade,
              'valor_total': valor,
            };
      if (itens.isEmpty) {
        _sacolaExpandida = false;
        _timerReservaSacola?.cancel();
        _timerReservaSacola = null;
        _segundosReservaSacola = 0;
      }
    });
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

  Widget _sacolaCompraEvento({VoidCallback? atualizarModalidades}) {
    final compra = _compraEvento ?? const <String, dynamic>{};
    final total = double.tryParse('${compra['valor_total'] ?? 0}') ?? 0;
    final itens = (compra['itens'] is List)
        ? (compra['itens'] as List).whereType<Map>().toList()
        : const <Map>[];
    final quantidadeInformada =
        int.tryParse('${compra['quantidade'] ?? 0}') ?? 0;
    final quantidadeDosItens = itens.fold<int>(
      0,
      (soma, item) => soma + (int.tryParse('${item['quantidade'] ?? 1}') ?? 1),
    );
    final quantidade = quantidadeDosItens > quantidadeInformada
        ? quantidadeDosItens
        : quantidadeInformada;
    return SafeArea(
      top: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE3A8),
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.amareloCerveja,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: itens.isEmpty || processandoCompra
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          atualizarModalidades?.call();
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_num_outlined, size: 21),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '$quantidade ${quantidade == 1 ? 'ingresso' : 'ingressos'} · ${ValueFormatters.moeda(total)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right, size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 38,
              child: FilledButton(
                onPressed: itens.isEmpty || processandoCompra
                    ? null
                    : () async {
                        Navigator.of(context).pop();
                        atualizarModalidades?.call();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amareloCerveja,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BeneficioIngresso> _beneficiosValidosDaReserva(
    Map<String, dynamic> reserva,
    List<BeneficioIngresso> beneficiosDoLote,
  ) {
    final dados = reserva['beneficios_validos'];
    if (dados is! List) return beneficiosDoLote;

    return dados
        .whereType<Map>()
        .map(
          (item) => BeneficioIngresso.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((beneficio) => beneficio.id > 0)
        .toList(growable: false);
  }

  String _nomeModalidade(EventoLote lote) {
    return lote.nomeModalidade.trim().isEmpty
        ? 'Ingresso'
        : lote.nomeModalidade;
  }

  Future<void> _abrirSelecaoIngressos({bool somenteCortesia = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'setor-ingressos'),
        builder: (_) => _TelaSelecaoIngressos(
          lotes: () => lotes,
          somenteCortesia: somenteCortesia,
          nomeEvento: evento?.titulo ?? 'Evento',
          dataEvento: DateFormatters.dataCompleta(evento?.dataInicio ?? '').replaceFirst(', às ', ' às '),
          imagemEvento: evento?.bannerUrl ?? '',
          segundosReserva: () => _segundosReservaSacola,
          verificarExpiracao: (tela) => unawaited(_verificarExpiracaoNaSelecao(tela)),
          totalSelecionado: () => _totalSelecionado + (int.tryParse('${_compraEvento?['quantidade'] ?? 0}') ?? 0),
          onComprar: _comprarSelecionados,
          onAtualizar: atualizarLotes,
          construirSetor: (opcoes, selecionar, somenteCortesia) => _cardSelecaoSetor(opcoes, onSelecionar: selecionar, somenteCortesia: somenteCortesia),
          construirModalidades: (opcoes, voltar, setorUnico) => _ModalidadesIngressoScreen(
            opcoes: opcoes,
            somenteCortesia: opcoes.every(_ehCortesia),
            nomeEvento: evento?.titulo ?? 'Evento',
            dataHoraEvento: DateFormatters.dataCompleta(evento?.dataInicio ?? '').replaceFirst(', às ', ' às '),
            imagemEventoUrl: evento?.bannerUrl ?? '',
            taxaPercentual: widget.loja.vrtaxaing,
            taxaMinima: widget.loja.vrtaxaminimaingresso,
            nomeModalidade: _nomeModalidade,
            onComprar: (lote, quantidade) => iniciarReserva(lote, quantidadeSelecionada: quantidade),
            quantidadeSelecionada: _quantidadeExibida,
            quantidadePendente: (id) => _quantidadesModalidades[id] ?? 0,
            totalSelecionado: () => _totalSelecionado + (int.tryParse('${_compraEvento?['quantidade'] ?? 0}') ?? 0),
            onSelecionar: _selecionarQuantidade,
            onComprarSelecionados: _comprarSelecionados,
            onEntenderTaxa: _abrirExplicacaoTaxas,
            compraEvento: _compraEvento,
            segundosReserva: () => _segundosReservaSacola,
            verificarExpiracao: (tela) => unawaited(_verificarExpiracaoNaSelecao(tela)),
            onAtualizar: atualizarLotes,
            setorUnico: setorUnico,
            onVoltar: voltar,
          ),
        ),
      ),
    );
    if (mounted) await carregarStatusLotes();
  }

  Widget _cardSelecaoSetor(List<EventoLote> opcoes, {required VoidCallback onSelecionar, required bool somenteCortesia}) {
    final lote = opcoes.first;
    final restantes = lote.qtDisponivel;
    final agora = HorarioBrasil.agora();
    final disponiveis = opcoes.where((opcao) => opcao.podeComprarEm(agora)).toList();
    final temCortesiaDisponivel = disponiveis.any(_ehCortesia);
    final pagos = disponiveis.where((opcao) => !_ehCortesia(opcao)).toList();
    final precos = (pagos.isEmpty ? disponiveis : pagos).map((opcao) => _ehCortesia(opcao) ? 0.0 : opcao.preco).toList()..sort();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFFE082)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelecionar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 56,
                child: Center(
                  child: Icon(
                    Icons.stadium_outlined,
                    color: Colors.blue.shade700,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lote.nomeSetor.trim().isEmpty
                          ? 'Setor não informado'
                          : 'Setor: ${lote.nomeSetor}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$restantes ${restantes == 1 ? 'restante' : 'restantes'}',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                    if (!somenteCortesia && precos.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        precos.first == precos.last
                            ? 'Preço: ${ValueFormatters.moeda(precos.first)}'
                            : 'Preços entre ${ValueFormatters.moeda(precos.first)} e ${ValueFormatters.moeda(precos.last)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                    if (!somenteCortesia && temCortesiaDisponivel) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.card_giftcard_outlined,
                              size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Cortesia disponível',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.blue.shade700),
            ],
          ),
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

  void _abrirExplicacaoTaxas() => mostrarExplicacaoTaxas(context);

  ButtonStyle _estiloLinksEvento() => TextButton.styleFrom(
    foregroundColor: Theme.of(context).colorScheme.primary,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
  );

  Future<void> _abrirContato(Uri uri) async {
    final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abriu && mounted) {
      AppSnackBar.erro(context, 'Não foi possível abrir este contato.');
    }
  }

  Widget _badgeEventoIniciado() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        'Evento já iniciado',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _faixaSituacaoEContato(EventoDetalhe detalhe) {
    final email = _primeiroContato(
      detalhe.emailEvento,
      detalhe.emailEstabelecimento,
      widget.loja.emailContato,
    );
    final whatsapp = _primeiroContato(
      detalhe.whatsappEvento,
      detalhe.whatsappEstabelecimento,
      _primeiroContato(widget.loja.whatsapp, widget.loja.nrtelloja),
    );
    final numeroWhatsApp = whatsapp.replaceAll(RegExp(r'\D'), '');
    final whatsappComDdi =
        numeroWhatsApp.length == 10 || numeroWhatsApp.length == 11
        ? '55$numeroWhatsApp'
        : numeroWhatsApp;
    final temContato = email.isNotEmpty || whatsappComDdi.isNotEmpty;

    if (!temContato) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Fale com o organizador',
            style: TextStyle(fontSize: 11, color: Colors.black87),
          ),
          if (email.isNotEmpty)
            TextButton.icon(
              onPressed: () =>
                  _abrirContato(Uri(scheme: 'mailto', path: email)),
              icon: const Icon(Icons.email_outlined, size: 15),
              label: const Text('E-mail'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
          if (whatsappComDdi.isNotEmpty)
            TextButton.icon(
              onPressed: () =>
                  _abrirContato(Uri.parse('https://wa.me/$whatsappComDdi')),
              icon: const Icon(Icons.chat_outlined, size: 15),
              label: const Text('WhatsApp'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 11),
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

  Widget _informacaoDoEvento({required IconData icone, required String texto}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.25,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
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
      appBar: ClubbarAppBar(
        titulo: 'Detalhes do evento',
        iconeTitulo: Icons.confirmation_number_rounded,
        corIconeTitulo: Colors.blue,
        tituloAlinhadoEsquerda: true,
        mostrarVoltar: true,
        mostrarSessao: false,
        onVoltar: () => unawaited(_confirmarSaida()),
        actions: [
          if (_compraEvento != null && _segundosReservaSacola > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_outlined, color: Colors.red, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${(_segundosReservaSacola ~/ 60).toString().padLeft(2, '0')}:${(_segundosReservaSacola % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ]),
            ),
        ],
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
                          Center(
                            child: Text(
                              (ev.nomeLoja.trim().isNotEmpty ? ev.nomeLoja : widget.loja.nome),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: SizedBox(
                              height: 200,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (ev.bannerUrl.trim().isNotEmpty)
                                    Image.network(
                                      ev.bannerUrl,
                                      width: double.infinity,
                                      fit: BoxFit.fill,
                                    )
                                  else
                                    Container(
                                      color: Colors.grey.shade300,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        size: 48,
                                      ),
                                    ),
                                  if (ev.jaIniciado)
                                    Positioned(
                                      left: 12,
                                      bottom: 12,
                                      child: _badgeEventoIniciado(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -22),
                            child: Center(
                              child: Builder(
                                builder: (botaoContext) => ElevatedButton.icon(
                                  onPressed: () =>
                                      compartilharEvento(botaoContext),
                                  icon: const Icon(Icons.ios_share, size: 18),
                                  label: const Text('Compartilhar'),
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
                          ),
                          if (lotes.any(_ehCortesia))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SizedBox(width: double.infinity, child: FilledButton.icon(
                                onPressed: () => _abrirSelecaoIngressos(somenteCortesia: true),
                                icon: const Icon(Icons.card_giftcard_outlined, size: 18),
                                label: const Text('Resgatar cortesia'),
                                style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                              )),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (lotes.any((lote) => !_ehCortesia(lote)))
                                Flexible(
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 38,
                                    child: FilledButton.icon(
                                      onPressed: () => _abrirSelecaoIngressos(),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        minimumSize: const Size(0, 38),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: const Icon(
                                        Icons.confirmation_number_outlined,
                                        size: 16,
                                      ),
                                      label: const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Comprar ingresso',
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (!lotes.any((lote) => !_ehCortesia(lote))) const Spacer(),
                              if (lotes.any((lote) => !_ehCortesia(lote))) const SizedBox(width: 10),
                              Flexible(
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 38,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      MainNavigationController.abrirTela(
                                        ProdutosLojaScreen(loja: widget.loja),
                                      );
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      minimumSize: const Size(0, 38),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: const Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 16,
                                    ),
                                    label: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Cardápio',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            'Comprar produto',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
                          if (ev.classificacaoEtaria.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _informacaoDoEvento(
                                    icone: Icons.verified_user_outlined,
                                    texto:
                                        'Classificação etária: ${ev.classificacaoEtaria}',
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const PoliticaCompraScreen(
                                            tipo: 'INGRESSO',
                                          ),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.policy_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Política de compra'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    textStyle: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          _faixaSituacaoEContato(ev),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.event_outlined,
                                      size: 20,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            formatarDataHora(ev.dataInicio),
                                            style: TextStyle(
                                              color: Colors.blue.shade700,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (ev.dataFim.trim().isNotEmpty)
                                            Text(
                                              DateFormatters.terminoEvento(
                                                ev.dataInicio,
                                                ev.dataFim,
                                              ),
                                              style: TextStyle(
                                                color: Colors.blue.shade700,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
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
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: Colors.grey.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        ev.enderecoFormatado,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.25,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (atracoesOrdenadas.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Atrações',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 60,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: atracoesOrdenadas.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(width: 10),
                                      itemBuilder: (context, index) {
                                        final atracao =
                                            atracoesOrdenadas[index];
                                        return SizedBox(
                                          width: 176,
                                          child: Material(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: InkWell(
                                              onTap: () =>
                                                  _abrirDetalhesAtracao(
                                                    atracao,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.grey.shade300,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    _fotoAtracao(
                                                      atracao,
                                                      tamanho: 34,
                                                    ),
                                                    const SizedBox(width: 7),
                                                    Expanded(
                                                      child: Text(
                                                        atracao.nome,
                                                        style: const TextStyle(
                                                          color: Colors.black87,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          height: 1.15,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const Icon(
                                                      Icons
                                                          .chevron_right_rounded,
                                                      size: 20,
                                                      color: Colors.blue,
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
                              ),
                            ),
                          ],

                          if (ev.descricao.trim().isNotEmpty &&
                              ev.descricao.trim().toLowerCase() != 'null') ...[
                            const SizedBox(height: 8),
                            const Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 5),
                              child: Text(
                                'Descrição do evento',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                ev.descricao,
                                textAlign: TextAlign.justify,
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
