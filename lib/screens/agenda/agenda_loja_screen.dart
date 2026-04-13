import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/evento.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../widgets/clubbar_app_bar.dart';

class AgendaEventosScreen extends StatefulWidget {
  final Loja loja;

  const AgendaEventosScreen({super.key, required this.loja});

  @override
  State<AgendaEventosScreen> createState() => _AgendaEventosScreenState();
}

class _AgendaEventosScreenState extends State<AgendaEventosScreen> {
  final apiService = ApiService();

  bool carregando = true;
  String? erro;
  List<Evento> eventos = [];

  @override
  void initState() {
    super.initState();
    carregarEventos();
  }

  Future<void> carregarEventos() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final lista = await apiService.buscarEventosPorLoja(widget.loja.id);

      setState(() {
        eventos = lista;
        carregando = false;
      });
    } catch (e) {
      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '');
        carregando = false;
      });
    }
  }

  String formatarCabecalhoData(String valor) {
    if (valor.trim().isEmpty) return 'DATA NÃO INFORMADA';

    try {
      final data = DateTime.parse(valor).toLocal();
      final diaSemana = DateFormat('EEE', 'pt_BR').format(data).toUpperCase();
      final dia = DateFormat('dd', 'pt_BR').format(data);
      final mes = DateFormat('MMM', 'pt_BR').format(data).toUpperCase();
      final hora = DateFormat('HH:mm', 'pt_BR').format(data);

      return '$diaSemana, $dia $mes · $hora';
    } catch (_) {
      return valor;
    }
  }

  String formatarLocal(Evento evento) {
    return evento.local.trim().isEmpty ? widget.loja.nome : evento.local;
  }

  Widget imagemEvento(String url) {
    if (url.trim().isEmpty) {
      return Container(
        width: 108,
        height: 78,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 108,
        height: 78,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 108,
          height: 78,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported),
        ),
      ),
    );
  }

  Widget itemEvento(Evento evento) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          imagemEvento(evento.bannerUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatarCabecalhoData(evento.data),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  evento.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatarLocal(evento),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
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

  Widget estadoVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            const Text(
              'Nenhum evento encontrado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Não há próximos eventos cadastrados para esta loja.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget erroWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 56),
            const SizedBox(height: 14),
            Text(
              erro ?? 'Erro ao carregar agenda',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: carregarEventos,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro != null
          ? erroWidget()
          : eventos.isEmpty
          ? estadoVazio()
          : RefreshIndicator(
              onRefresh: carregarEventos,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Agenda - ${widget.loja.nome}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Próximos eventos desta loja',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  ...eventos.map(itemEvento),
                ],
              ),
            ),
    );
  }
}
