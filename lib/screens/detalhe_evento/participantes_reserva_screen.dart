import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/cpf_utils.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../pagamento/escolha_pagamento_screen.dart';
import '../pagamento/pagamento_sucesso_screen.dart';

class ParticipantesReservaScreen extends StatefulWidget {
  final Loja loja;
  final Map<String, dynamic> reserva;
  final String nomeEvento;
  final String dataHoraEvento;
  final String nomeLote;
  final String nomeSetor;
  final String modalidade;
  final String beneficio;

  const ParticipantesReservaScreen({
    super.key,
    required this.loja,
    required this.reserva,
    required this.nomeEvento,
    required this.dataHoraEvento,
    required this.nomeLote,
    required this.nomeSetor,
    required this.modalidade,
    required this.beneficio,
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
  Timer? timer;
  late DateTime expiraEm;
  Duration restante = Duration.zero;
  bool salvando = false;

  @override
  void initState() {
    super.initState();
    final quantidade = int.tryParse('${widget.reserva['quantidade']}') ?? 1;
    for (var i = 0; i < quantidade; i++) {
      nomes.add(TextEditingController());
      cpfs.add(TextEditingController());
    }
    expiraEm =
        DateTime.tryParse('${widget.reserva['data_expiracao']}') ??
        DateTime.now().add(const Duration(minutes: 15));
    _tick();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final valor = expiraEm.difference(DateTime.now());
    if (!mounted) return;
    setState(() => restante = valor.isNegative ? Duration.zero : valor);
    if (valor <= Duration.zero) {
      timer?.cancel();
      AppSnackBar.erro(
        context,
        'O tempo para concluir a compra de ingressos expirou.',
      );
      Navigator.pop(context);
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
    final participantes = <Map<String, String>>[];
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
      participantes.add({'nome': nome, 'cpf': CpfUtils.somenteNumeros(cpf)});
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
            totalPagar: double.tryParse('${reserva['valor_total']}'),
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

  Widget _linhaResumo(IconData icone, String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 19, color: Colors.black87),
          const SizedBox(width: 9),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(color: Colors.black87, height: 1.3),
                children: [
                  TextSpan(
                    text: '$titulo: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: valor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutos = restante.inMinutes.toString().padLeft(2, '0');
    final segundos = (restante.inSeconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      backgroundColor: const Color(0xFFF5F5F5),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            widget.nomeEvento,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: _contador(minutos, segundos),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Confira os ingressos escolhidos',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  _linhaResumo(
                    Icons.event_outlined,
                    'Data e hora',
                    widget.dataHoraEvento,
                  ),
                  _linhaResumo(
                    Icons.confirmation_number_outlined,
                    'Lote',
                    widget.nomeLote,
                  ),
                  _linhaResumo(Icons.place_outlined, 'Setor', widget.nomeSetor),
                  _linhaResumo(
                    Icons.sell_outlined,
                    'Modalidade',
                    widget.modalidade,
                  ),
                  _linhaResumo(
                    Icons.verified_user_outlined,
                    'Benefício',
                    widget.beneficio,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < nomes.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Participante ${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nomes[i],
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: cpfs[i],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'CPF'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: salvando ? null : continuar,
            icon: const Icon(Icons.payment),
            label: const Text('Continuar para pagamento'),
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
    );
  }
}
