import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/evento.dart';
import '../../services/api_service.dart';
import '../../services/main_navigation_controller.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/clubbar_page_header.dart';
import '../detalhe_evento/detalhe_evento_screen.dart';

class CortesiasDisponiveisScreen extends StatelessWidget {
  final List<Evento> eventos;

  const CortesiasDisponiveisScreen({super.key, required this.eventos});

  String _formatarData(String valor) {
    final data = DateTime.tryParse(valor)?.toLocal();
    if (data == null) return 'Data não informada';
    return DateFormat("EEEE, dd/MM 'às' HH'h'", 'pt_BR').format(data);
  }

  Widget _imagemEvento(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 100,
        height: 76,
        color: Colors.grey.shade100,
        child: url.trim().isEmpty
            ? const Icon(Icons.local_activity_outlined, size: 32)
            : Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.local_activity_outlined, size: 32),
              ),
      ),
    );
  }

  Future<void> _abrirEvento(BuildContext context, Evento evento) async {
    try {
      final loja = await ApiService().buscarDadosLoja(evento.lojaId);
      if (!context.mounted) return;
      MainNavigationController.abrirTela(
        DetalheEventoScreen(eventoId: evento.id, loja: loja),
      );
    } catch (_) {
      if (!context.mounted) return;
      AppSnackBar.erro(
        context,
        'Não foi possível carregar os dados do estabelecimento.',
      );
    }
  }

  Widget _cardEvento(BuildContext context, Evento evento) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _abrirEvento(context, evento),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _imagemEvento(evento.bannerUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatarData(evento.data),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF168B3A),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      evento.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      evento.nomeLoja,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    const SizedBox(height: 7),
                    const Row(
                      children: [
                        Icon(
                          Icons.card_giftcard_rounded,
                          color: Color(0xFF168B3A),
                          size: 17,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Cortesia disponível',
                          style: TextStyle(
                            color: Color(0xFF168B3A),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(
        titulo: 'Cortesias',
        mostrarVoltar: true,
        mostrarSessao: false,
        mostrarLogo: false,
      ),
      body: Column(
        children: [
          const ClubbarPageHeader(
            titulo: 'Cortesias disponíveis',
            subtitulo: 'Escolha seu convite gratuito',
            icone: Icons.card_giftcard_rounded,
            corIcone: Color(0xFF168B3A),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: eventos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _cardEvento(
                context,
                eventos[index],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
