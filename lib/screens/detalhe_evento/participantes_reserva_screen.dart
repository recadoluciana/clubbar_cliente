import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../models/evento_lote.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/cpf_utils.dart';
import '../../utils/horario_brasil.dart';
import '../../utils/value_formatters.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/prazo_expirado_dialog.dart';
import '../pagamento/escolha_pagamento_screen.dart';
import '../pagamento/pagamento_sucesso_screen.dart';

class ParticipantesReservaScreen extends StatefulWidget {
  final Loja loja;
  final Map<String, dynamic> reserva;
  final String nomeEvento;
  final String dataHoraEvento;
  final String imagemEventoUrl;
  final String nomeLote;
  final String nomeSetor;
  final String modalidade;
  final List<BeneficioIngresso> beneficios;

  const ParticipantesReservaScreen({
    super.key,
    required this.loja,
    required this.reserva,
    required this.nomeEvento,
    required this.dataHoraEvento,
    this.imagemEventoUrl = '',
    required this.nomeLote,
    required this.nomeSetor,
    required this.modalidade,
    this.beneficios = const [],
  });

  @override
  State<ParticipantesReservaScreen> createState() =>
      _ParticipantesReservaScreenState();
}

class _ParticipantesReservaScreenState
    extends State<ParticipantesReservaScreen> {
  final ApiService api = ApiService();
  final List<TextEditingController> nomes = [];
  final List<TextEditingController> cpfs = [];
  final List<int?> beneficiosParticipantes = [];
  final List<Map<String, dynamic>> dadosParticipantes = [];
  Timer? timer;
  late DateTime expiraEm;
  Duration restante = Duration.zero;
  bool salvando = false;
  bool _reservaFinalizada = false;
  bool _reservaCancelada = false;
  bool _verificandoExpiracao = false;
  bool _checkoutIniciado = false;

  Future<void> _removerParticipante(int indice) async {
    if (salvando || _verificandoExpiracao) return;
    final reservaId = int.tryParse('${dadosParticipantes[indice]['reserva_ingresso_id'] ?? widget.reserva['reserva_ingresso_id']}');
    final clienteId = int.tryParse('${widget.reserva['cliente_id']}');
    final compraId = int.tryParse('${widget.reserva['compra_evento_id']}');
    if (reservaId == null || clienteId == null) return;
    setState(() => salvando = true);
    try {
      final resposta = compraId != null
          ? await api.removerIngressoCompraEvento(
              compraEventoId: compraId,
              reservaId: reservaId,
              clienteId: clienteId,
            )
          : await api.cancelarReservaIngresso(
              reservaId: reservaId,
              clienteId: clienteId,
            );
      final itens = (resposta['itens'] as List?)
          ?.whereType<Map>()
          .expand<Map<String, dynamic>>((item) {
            final dados = Map<String, dynamic>.from(item);
            final quantidade = int.tryParse('${dados['quantidade'] ?? 1}') ?? 1;
            return List<Map<String, dynamic>>.filled(quantidade, dados);
          })
          .toList();
      if (itens == null || itens.isEmpty) {
        if (mounted) Navigator.pop(context, true);
        return;
      }
      for (final controller in [...nomes, ...cpfs]) {
        controller.dispose();
      }
      nomes.clear();
      cpfs.clear();
      beneficiosParticipantes.clear();
      dadosParticipantes
        ..clear()
        ..addAll(itens);
      for (var i = 0; i < itens.length; i++) {
        nomes.add(TextEditingController());
        cpfs.add(TextEditingController());
        beneficiosParticipantes.add(null);
      }
      if (mounted) setState(() {});
    } catch (erro) {
      if (mounted) AppSnackBar.erro(context, api.mensagemErroAmigavel(erro));
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  @override
  void initState() {
    super.initState();
    var quantidade = int.tryParse('${widget.reserva['quantidade']}') ?? 1;
    final itens = widget.reserva['itens'];
    if (itens is List) {
      for (final item in itens.whereType<Map>()) {
        final quantidadeItem = int.tryParse('${item['quantidade']}') ?? 1;
        // A compra agrupada pode chegar com o resumo antigo (quantidade 1)
        // enquanto a lista de itens já contém duas cortesias. A lista é a
        // fonte correta para montar um participante por ingresso.
        for (var i = 0; i < quantidadeItem; i++) {
          dadosParticipantes.add(Map<String, dynamic>.from(item));
        }
      }
      final quantidadeDosItens = dadosParticipantes.length;
      if (quantidadeDosItens > quantidade) quantidade = quantidadeDosItens;
    }
    for (var i = 0; i < quantidade; i++) {
      nomes.add(TextEditingController());
      cpfs.add(TextEditingController());
      beneficiosParticipantes.add(null);
      if (dadosParticipantes.length <= i) {
        dadosParticipantes.add(widget.reserva);
      }
    }
    expiraEm =
        _expiracaoDaResposta(widget.reserva) ??
        HorarioBrasil.agora().add(const Duration(minutes: 35));
    _tick();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  DateTime? _expiracaoDaResposta(Map<String, dynamic> reserva) {
    final segundos = int.tryParse('${reserva['segundos_restantes']}');
    if (segundos != null && segundos >= 0) {
      return HorarioBrasil.agora().add(Duration(seconds: segundos));
    }
    return HorarioBrasil.deTextoBrasil(reserva['data_expiracao']);
  }

  void _tick() {
    final valor = expiraEm.difference(HorarioBrasil.agora());
    if (!mounted) return;
    setState(() => restante = valor.isNegative ? Duration.zero : valor);
    if (valor <= Duration.zero) {
      timer?.cancel();
      unawaited(_verificarExpiracao());
    }
  }

  Future<void> _verificarExpiracao() async {
    if (_verificandoExpiracao || _reservaFinalizada) return;
    if (mounted) setState(() => _verificandoExpiracao = true);
    try {
      final reservaId = int.parse('${widget.reserva['reserva_ingresso_id']}');
      final clienteId = int.parse('${widget.reserva['cliente_id']}');
      final atual = await api.consultarReserva(
        reservaId: reservaId,
        clienteId: clienteId,
      );
      if (!mounted) return;
      final pagamento = (atual['status_pagamento'] ?? '')
          .toString()
          .toUpperCase();
      if (pagamento == 'PAGO') {
        _reservaFinalizada = true;
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                _telaSucesso(_valorTotalComTaxa(widget.reserva) <= 0),
          ),
        );
        return;
      }
      if (pagamento == 'ESTORNADO' || pagamento == 'REFUNDED') {
        _reservaCancelada = true;
        await mostrarPrazoExpirado(context, tipo: PrazoExpiradoTipo.estorno);
        if (mounted) Navigator.pop(context);
        return;
      }
      final segundos = int.tryParse('${atual['segundos_restantes']}');
      final situacao = (atual['status'] ?? '').toString().toUpperCase();
      if (segundos != null &&
          segundos > 0 &&
          !{'EXPIRADA', 'CANCELADA'}.contains(situacao)) {
        expiraEm = HorarioBrasil.agora().add(Duration(seconds: segundos));
        _tick();
        timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
        return;
      }
      if (segundos == null && !{'EXPIRADA', 'CANCELADA'}.contains(situacao)) {
        throw Exception('Não foi possível confirmar a validade da reserva.');
      }
      _reservaCancelada = true;
      await mostrarPrazoExpirado(context, tipo: PrazoExpiradoTipo.reserva);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        AppSnackBar.aviso(
          context,
          'Não foi possível verificar a reserva. Confira sua conexão e tente novamente.',
        );
        timer = Timer.periodic(const Duration(seconds: 10), (_) => _tick());
      }
    } finally {
      if (mounted) setState(() => _verificandoExpiracao = false);
    }
  }

  Future<void> _cancelarReservaSeNecessario() async {
    if (_reservaFinalizada || _reservaCancelada || _checkoutIniciado) return;
    _reservaCancelada = true;
    final reservaId =
        int.tryParse('${widget.reserva['reserva_ingresso_id']}') ?? 0;
    final clienteId = int.tryParse('${widget.reserva['cliente_id']}') ?? 0;
    if (reservaId <= 0 || clienteId <= 0) return;
    try {
      await api.cancelarReservaIngresso(
        reservaId: reservaId,
        clienteId: clienteId,
      );
    } catch (_) {
      // Se o app for fechado abruptamente, a expiração no servidor libera a
      // reserva no prazo definido. Uma venda já confirmada também não pode
      // ser cancelada por esta ação.
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final c in [...nomes, ...cpfs]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> continuar() async {
    if (_verificandoExpiracao || restante <= Duration.zero) return;
    final participantes = <Map<String, dynamic>>[];
    for (var i = 0; i < nomes.length; i++) {
      final nome = nomes[i].text.trim();
      final cpf = cpfs[i].text.trim();
      if (nome.length < 3 || !CpfUtils.validar(cpf)) {
        AppSnackBar.erro(
          context,
          'Confira nome e CPF do participante ${i + 1}.',
        );
        return;
      }
      final beneficioId = beneficiosParticipantes[i];
      // A compra pode reunir modalidades diferentes. O benefício só é
      // obrigatório para o item/modalidade que realmente oferece benefícios;
      // cortesia e ingresso inteiro não devem herdar a exigência de outro item.
      if (_beneficiosDoParticipante(i).isNotEmpty && beneficioId == null) {
        AppSnackBar.erro(
          context,
          'Escolha o benefício do participante ${i + 1}.',
        );
        return;
      }
      participantes.add({
        'nome': nome,
        'cpf': CpfUtils.somenteNumeros(cpf),
        if (beneficioId case final int id) 'beneficio_id': id,
      });
    }
    if (participantes.map((e) => e['cpf']).toSet().length !=
        participantes.length) {
      AppSnackBar.erro(
        context,
        'Cada participante deve possuir um CPF distinto.',
      );
      return;
    }
    setState(() => salvando = true);
    try {
      final reserva = await api.salvarParticipantesReserva(
        reservaId: int.parse('${widget.reserva['reserva_ingresso_id']}'),
        participantes: participantes,
      );
      if (!mounted) return;
      expiraEm = _expiracaoDaResposta(reserva) ?? expiraEm;
      if (reserva['gratuito'] == true || reserva['venda_id'] != null) {
        _reservaFinalizada = true;
        timer?.cancel();
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _telaSucesso(
              reserva['gratuito'] == true ||
                  _valorTotalComTaxa(widget.reserva) <= 0,
            ),
          ),
        );
        return;
      }
      final valorTotalComTaxa = _valorTotalComTaxa(reserva);
      final ingressos = _itensFinanceiros(reserva, 'valor_unitario');
      final taxas = _itensFinanceiros(reserva, 'valor_taxa_unitaria');
      timer?.cancel();
      _checkoutIniciado = true;
      final reservaEncerrada = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => EscolhaPagamentoScreen(
            loja: widget.loja,
            totalProdutos: 0,
            totalIngressos: ingressos,
            taxaConveniencia: taxas,
            totalPagar: valorTotalComTaxa,
            reservaIngressoId: int.parse('${reserva['reserva_ingresso_id']}'),
            reservaExpiracao: expiraEm,
          ),
        ),
      );
      if (mounted && reservaEncerrada == false) {
        _reservaCancelada = true;
        Navigator.pop(context);
        return;
      }
      if (mounted && !_reservaFinalizada) {
        try {
          final atual = await api.consultarReserva(
            reservaId: int.parse('${widget.reserva['reserva_ingresso_id']}'),
            clienteId: int.parse('${widget.reserva['cliente_id']}'),
          );
          if (!mounted) return;
          if ((atual['status_pagamento'] ?? '').toString().toUpperCase() ==
              'PAGO') {
            _reservaFinalizada = true;
            return;
          }
          expiraEm = _expiracaoDaResposta(atual) ?? expiraEm;
          _tick();
          if (mounted && restante > Duration.zero) {
            timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
          }
        } catch (_) {
          // Sem confirmação do servidor, não cancelamos uma reserva que pode
          // ter sido prorrogada ou paga durante o checkout.
        }
      }
    } catch (e) {
      if (mounted) {
        final mensagem = api.mensagemErroAmigavel(e);
        if (mensagem.contains(
          'Este CPF já resgatou uma cortesia deste evento.',
        )) {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => PopScope(
              canPop: false,
              child: AlertDialog(
                title: const Text('Cortesia já resgatada'),
                content: Text(mensagem),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Entendi'),
                  ),
                ],
              ),
            ),
          );
        } else {
          AppSnackBar.erro(context, mensagem);
        }
      }
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  Widget _contador(String minutos, String segundos) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.timer_outlined, color: Colors.red, size: 19),
        const SizedBox(width: 6),
        Text(
          'Tempo para concluir a compra: $minutos:$segundos',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _telaSucesso(bool gratuito) => PagamentoSucessoScreen(
    lojaDestino: widget.loja,
    tituloAppBar: gratuito ? 'Resgate' : 'Pagamento',
    tituloSucesso: gratuito ? 'Resgate realizado com sucesso' : null,
    descricaoSucesso: gratuito
        ? 'Seu ingresso está disponível na Carteira.'
        : null,
  );

  double _valorTotalComTaxa(Map<String, dynamic> reserva) {
    if (reserva['itens'] is List || reserva['compra_evento_id'] != null) {
      return double.tryParse('${reserva['valor_total']}') ?? 0;
    }
    final valorUnitario = double.tryParse('${reserva['valor_unitario']}') ?? 0;
    final taxaUnitaria =
        double.tryParse('${reserva['valor_taxa_unitaria']}') ?? 0;
    final quantidade = double.tryParse('${reserva['quantidade']}') ?? 0;
    final totalCalculado = (valorUnitario + taxaUnitaria) * quantidade;

    return totalCalculado > 0
        ? totalCalculado
        : (double.tryParse('${reserva['valor_total']}') ?? 0);
  }

  double _itensFinanceiros(Map<String, dynamic> reserva, String campo) {
    final itens = reserva['itens'];
    if (itens is List) {
      return itens.fold<double>(0, (total, item) {
        if (item is! Map) return total;
        final unitario = double.tryParse('${item[campo] ?? 0}') ?? 0;
        final quantidade = int.tryParse('${item['quantidade'] ?? 1}') ?? 1;
        return total + unitario * quantidade;
      });
    }
    final unitario = double.tryParse('${reserva[campo] ?? 0}') ?? 0;
    final quantidade = int.tryParse('${reserva['quantidade'] ?? 1}') ?? 1;
    return unitario * quantidade;
  }

  Widget _resumoCompacto(String titulo, String valor) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(color: Colors.black87, fontSize: 13),
        children: [
          TextSpan(
            text: '$titulo: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: valor),
        ],
      ),
    );
  }

  List<BeneficioIngresso> _beneficiosDoParticipante(int indice) {
    final dados = indice < dadosParticipantes.length
        ? dadosParticipantes[indice]['beneficios_validos']
        : null;
    if (dados is! List) return const [];
    return dados
        .whereType<Map>()
        .map(
          (item) => BeneficioIngresso.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.id > 0)
        .toList(growable: false);
  }

  Widget _dadosIngresso(int indice) {
    final item = indice < dadosParticipantes.length
        ? dadosParticipantes[indice]
        : widget.reserva;
    final lote = '${item['nome_lote'] ?? ''}'.trim();
    final setor = '${item['nome_setor'] ?? ''}'.trim();
    final modalidade = '${item['nome_modalidade'] ?? ''}'.trim();
    final nomeNormalizado = modalidade.toLowerCase();
    final Color corModalidade;
    if (nomeNormalizado.contains('cortesia')) {
      corModalidade = Colors.green.shade700;
    } else if (nomeNormalizado.contains('meia')) {
      corModalidade = Colors.blue.shade700;
    } else if (nomeNormalizado.contains('inteira')) {
      corModalidade = Colors.amber.shade900;
    } else {
      corModalidade = Colors.black;
    }
    final primeiraLinha = [
      if (lote.isNotEmpty) 'Lote: $lote',
      if (setor.isNotEmpty) 'Setor: $setor',
    ];
    if (primeiraLinha.isEmpty && modalidade.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(
        [
          if (primeiraLinha.isNotEmpty) primeiraLinha.join('  •  '),
          if (modalidade.isNotEmpty) 'Modalidade: $modalidade',
        ].join('\n'),
        style: TextStyle(
          fontSize: 14,
          color: corModalidade,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _logoEvento() {
    final imagem = widget.imagemEventoUrl.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 64,
        height: 64,
        child: imagem.isEmpty
            ? Container(
                color: Colors.white.withValues(alpha: 0.7),
                child: const Icon(
                  Icons.local_activity_outlined,
                  color: Colors.black87,
                  size: 30,
                ),
              )
            : Image.network(
                imagem,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.white.withValues(alpha: 0.7),
                  child: const Icon(
                    Icons.local_activity_outlined,
                    color: Colors.black87,
                    size: 30,
                  ),
                ),
              ),
      ),
    );
  }

  InputDecoration _campoParticipante(String texto) {
    return InputDecoration(
      labelText: texto,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.green, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutos = restante.inMinutes.toString().padLeft(2, '0');
    final segundos = (restante.inSeconds % 60).toString().padLeft(2, '0');
    final valorTotal = _valorTotalComTaxa(widget.reserva);
    final ehCortesia = valorTotal <= 0;
    return PopScope(
      // Voltar para a tela de modalidades não cancela a reserva. O usuário
      // pode revisar a sacola e retornar para preencher os participantes;
      // cancelamento ocorre somente por expiração ou ação explícita.
      onPopInvokedWithResult: (_, _) {},
      child: Scaffold(
        appBar: ClubbarAppBar(
          titulo: widget.loja.nome,
          mostrarVoltar: true,
          mostrarSessao: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.red, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '$minutos:$segundos',
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
        backgroundColor: const Color(0xFFF5F5F5),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFF9E9), Color(0xFFFFE6A6)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFECCB72)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _logoEvento(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.nomeEvento,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 7),
                              _resumoCompacto('Data', widget.dataHoraEvento),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (valorTotal != 0) ...[
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Subtotal',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            ValueFormatters.moeda(valorTotal),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < nomes.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_outline_rounded,
                            size: 17,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Participante ${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Excluir participante',
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: salvando ? null : () => _removerParticipante(i),
                        ),
                      ],
                    ),
                    _dadosIngresso(i),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nomes[i],
                      decoration: _campoParticipante('Nome completo'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: cpfs[i],
                      keyboardType: TextInputType.number,
                      decoration: _campoParticipante('CPF'),
                    ),
                    if (_beneficiosDoParticipante(i).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: beneficiosParticipantes[i],
                        isDense: true,
                        decoration: _campoParticipante('Benefício'),
                        items: _beneficiosDoParticipante(i)
                            .map(
                              (beneficio) => DropdownMenuItem<int>(
                                value: beneficio.id,
                                child: Text(beneficio.nome),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (valor) =>
                            setState(() => beneficiosParticipantes[i] = valor),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed:
                  salvando || _verificandoExpiracao || restante <= Duration.zero
                  ? null
                  : continuar,
              icon: Icon(
                ehCortesia ? Icons.card_giftcard_rounded : Icons.payment,
              ),
              label: Text(
                ehCortesia ? 'Resgatar cortesia' : 'Continuar para pagamento',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ehCortesia
                    ? Colors.green.shade700
                    : Colors.amber,
                foregroundColor: ehCortesia ? Colors.white : Colors.black,
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            const SizedBox(height: 12),
            _contador(minutos, segundos),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
