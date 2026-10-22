import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/evento_lote.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/cpf_utils.dart';
import '../../utils/horario_brasil.dart';
import '../../utils/value_formatters.dart';
import '../../widgets/clubbar_app_bar.dart';
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
  Timer? timer;
  late DateTime expiraEm;
  Duration restante = Duration.zero;
  bool salvando = false;
  bool _reservaFinalizada = false;
  bool _reservaCancelada = false;

  @override
  void initState() {
    super.initState();
    final quantidade = int.tryParse('${widget.reserva['quantidade']}') ?? 1;
    for (var i = 0; i < quantidade; i++) {
      nomes.add(TextEditingController());
      cpfs.add(TextEditingController());
      beneficiosParticipantes.add(null);
    }
    expiraEm =
        HorarioBrasil.deTextoBrasil(widget.reserva['data_expiracao']) ??
        HorarioBrasil.agora().add(const Duration(minutes: 5));
    _tick();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final valor = expiraEm.difference(HorarioBrasil.agora());
    if (!mounted) return;
    setState(() => restante = valor.isNegative ? Duration.zero : valor);
    if (valor <= Duration.zero) {
      timer?.cancel();
      unawaited(_cancelarReservaSeNecessario());
      AppSnackBar.erro(
        context,
        'O tempo para concluir a compra de ingressos expirou.',
      );
      Navigator.pop(context);
    }
  }

  Future<void> _cancelarReservaSeNecessario() async {
    if (_reservaFinalizada || _reservaCancelada) return;
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
      // reserva em até cinco minutos. Uma venda já confirmada também não pode
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
      if (widget.beneficios.isNotEmpty && beneficioId == null) {
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
      if (reserva['gratuito'] == true || reserva['venda_id'] != null) {
        _reservaFinalizada = true;
        timer?.cancel();
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const PagamentoSucessoScreen(sucesso: true, cashbackGerado: 0),
          ),
        );
        return;
      }
      final valorTotalComTaxa = _valorTotalComTaxa(reserva);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EscolhaPagamentoScreen(
            loja: widget.loja,
            totalProdutos: 0,
            totalIngressos:
                double.tryParse('${reserva['valor_unitario']}')! *
                int.parse('${reserva['quantidade']}'),
            taxaConveniencia:
                double.tryParse('${reserva['valor_taxa_unitaria']}')! *
                int.parse('${reserva['quantidade']}'),
            totalPagar: valorTotalComTaxa,
            reservaIngressoId: int.parse('${reserva['reserva_ingresso_id']}'),
            reservaExpiracao: expiraEm,
          ),
        ),
      );
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, api.mensagemErroAmigavel(e));
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

  double _valorTotalComTaxa(Map<String, dynamic> reserva) {
    final valorUnitario = double.tryParse('${reserva['valor_unitario']}') ?? 0;
    final taxaUnitaria =
        double.tryParse('${reserva['valor_taxa_unitaria']}') ?? 0;
    final quantidade = double.tryParse('${reserva['quantidade']}') ?? 0;
    final totalCalculado = (valorUnitario + taxaUnitaria) * quantidade;

    return totalCalculado > 0
        ? totalCalculado
        : (double.tryParse('${reserva['valor_total']}') ?? 0);
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
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_cancelarReservaSeNecessario());
      },
      child: Scaffold(
        appBar: ClubbarAppBar(
          titulo: widget.loja.nome,
          mostrarVoltar: true,
          mostrarSessao: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$minutos:$segundos',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: [
                        _resumoCompacto('Modalidade', widget.modalidade),
                        _resumoCompacto('Setor', widget.nomeSetor),
                        _resumoCompacto('Lote', widget.nomeLote),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Valor a pagar',
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
                      ],
                    ),
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
                    if (widget.beneficios.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: beneficiosParticipantes[i],
                        isDense: true,
                        decoration: _campoParticipante('Benefício'),
                        items: widget.beneficios
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
              onPressed: salvando ? null : continuar,
              icon: Icon(
                ehCortesia ? Icons.card_giftcard_rounded : Icons.payment,
              ),
              label: Text(
                ehCortesia ? 'Resgatar cortesia' : 'Continuar para pagamento',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
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
