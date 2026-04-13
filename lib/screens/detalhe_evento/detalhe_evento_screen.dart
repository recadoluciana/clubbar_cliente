import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/evento.dart';
import '../../models/evento_detalhe.dart';
import '../../models/evento_lote.dart';
import '../../services/api_service.dart';

class DetalheEventoScreen extends StatefulWidget {
  final Evento evento;

  const DetalheEventoScreen({super.key, required this.evento});

  @override
  State<DetalheEventoScreen> createState() => _DetalheEventoScreenState();
}

class _DetalheEventoScreenState extends State<DetalheEventoScreen> {
  final apiService = ApiService();

  bool carregando = true;
  String? erro;
  EventoDetalhe? detalhe;
  List<EventoLote> lotes = [];

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final resultados = await Future.wait([
        apiService.buscarDetalheEvento(widget.evento.id),
        apiService.buscarLotesDoEvento(widget.evento.id),
      ]);

      final detalheEvento = resultados[0] as EventoDetalhe;
      final lotesEvento = resultados[1] as List<EventoLote>;

      setState(() {
        detalhe = detalheEvento;
        lotes = lotesEvento;
        carregando = false;
      });
    } catch (e) {
      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '');
        carregando = false;
      });
    }
  }

  String formatarDataHora(String valor) {
    if (valor.trim().isEmpty) return 'Não informado';

    try {
      final data = DateTime.parse(valor).toLocal();
      return DateFormat('dd/MM/yyyy - HH:mm', 'pt_BR').format(data);
    } catch (_) {
      return valor;
    }
  }

  Color corStatusLote(String status) {
    switch (status.toUpperCase()) {
      case 'ATIVO':
        return Colors.green;
      case 'ESGOTADO':
        return Colors.red;
      case 'ENCERRADO':
        return Colors.orange;
      case 'INATIVO':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _linhaInfo(IconData icon, String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor.trim().isEmpty ? 'Não informado' : valor,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardLote(EventoLote lote) {
    final cor = corStatusLote(lote.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lote.nome,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  lote.status,
                  style: TextStyle(
                    color: cor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'R\$ ${lote.preco.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total: ${lote.qtTotal}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              Expanded(
                child: Text(
                  'Vendidos: ${lote.qtVendida}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Disponíveis: ${lote.qtDisponivel}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            'Venda: ${formatarDataHora(lote.dataInicioVenda)} até ${formatarDataHora(lote.dataFimVenda)}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 56),
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

  @override
  Widget build(BuildContext context) {
    final ev = detalhe;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro != null || ev == null
          ? _estadoErro()
          : RefreshIndicator(
              onRefresh: carregarDados,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 280,
                    pinned: true,
                    backgroundColor: const Color(0xFF111111),
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        ev.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          ev.bannerUrl.isNotEmpty
                              ? Image.network(
                                  ev.bannerUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      Container(color: Colors.grey.shade300),
                                )
                              : Container(color: Colors.grey.shade300),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black54,
                                  Colors.black87,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ev.titulo,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _linhaInfo(
                                  Icons.calendar_month_outlined,
                                  'Data de início',
                                  formatarDataHora(ev.dataInicio),
                                ),
                                _linhaInfo(
                                  Icons.event_outlined,
                                  'Data de término',
                                  formatarDataHora(ev.dataFim),
                                ),
                                _linhaInfo(
                                  Icons.location_on_outlined,
                                  'Local',
                                  ev.local,
                                ),
                                _linhaInfo(
                                  Icons.map_outlined,
                                  'Endereço',
                                  ev.endereco,
                                ),
                                _linhaInfo(
                                  Icons.storefront_outlined,
                                  'Loja',
                                  ev.nomeLoja,
                                ),
                                _linhaInfo(
                                  Icons.location_city_outlined,
                                  'Cidade',
                                  ev.cidade,
                                ),
                              ],
                            ),
                          ),
                          if (ev.descricao.trim().isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Descrição do evento',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    ev.descricao,
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      height: 1.45,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          const Text(
                            'Lotes',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (lotes.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Este evento ainda não possui lotes cadastrados.',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            )
                          else
                            ...lotes.map(_cardLote),
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
