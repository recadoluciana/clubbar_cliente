import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/cpf_utils.dart';
import '../../widgets/clubbar_page_header.dart';
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
  bool _reservaFinalizada = false;
  bool _reservaCancelada = false;

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
        DateTime.now().add(const Duration(minutes: 5));
    _tick();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final valor = expiraEm.difference(DateTime.now());
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

  Widget _linhaResumo(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutos = restante.inMinutes.toString().padLeft(2, '0');
    final segundos = (restante.inSeconds % 60).toString().padLeft(2, '0');
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_cancelarReservaSeNecessario());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Informe o(s) participante(s)'),
          centerTitle: true,
        ),
        backgroundColor: const Color(0xFFF5F5F5),
        body: Column(
          children: [
            ClubbarPageHeader(
              titulo: widget.nomeEvento,
              subtitulo: 'Estabelecimento: ${widget.loja.nome}',
              icone: Icons.storefront_rounded,
              imagemAvatarUrl: widget.loja.imagemUrl,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _contador(minutos, segundos),
                  const SizedBox(height: 14),
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Confira os dados abaixo',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _linhaResumo('Data e hora', widget.dataHoraEvento),
                          _linhaResumo('Lote', widget.nomeLote),
                          _linhaResumo('Setor', widget.nomeSetor),
                          _linhaResumo('Modalidade', widget.modalidade),
                          _linhaResumo('Benefício', widget.beneficio),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
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
                              decoration: const InputDecoration(
                                labelText: 'CPF',
                              ),
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
            ),
          ],
        ),
      ),
    );
  }
}
