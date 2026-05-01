import 'package:flutter/material.dart';

import '../../models/evento.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../detalhe_evento/detalhe_evento_screen.dart';
import '../carrinho/carrinho_screen.dart';
import '../../utils/date_formatters.dart';

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

  // Depois ligamos isso no /carrinho/qt
  int quantidadeCarrinho = 3;

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
    return DateFormatters.dataCompleta(valor);
  }

  String formatarLocal(Evento evento) {
    return evento.local.trim().isEmpty ? widget.loja.nome : evento.local;
  }

  Widget _badgeCarrinho() {
    if (quantidadeCarrinho <= 0) return const SizedBox();

    return Positioned(
      right: 4,
      top: 5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
        child: Text(
          quantidadeCarrinho > 99 ? '99+' : '$quantidadeCarrinho',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
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
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DetalheEventoScreen(eventoId: evento.id, loja: widget.loja),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget estadoVazio() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget erroWidget() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
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

  SliverAppBar topBarLoja() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: const Color(0xFF050505),
      elevation: 0,
      centerTitle: true,
      title: Text(
        widget.loja.nome,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CarrinhoScreen(loja: widget.loja),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              _badgeCarrinho(),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.loja.nome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CarrinhoScreen(loja: widget.loja),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.shopping_cart_outlined,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                _badgeCarrinho(),
              ],
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: carregarEventos,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agenda - ${widget.loja.nome}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Próximos eventos',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ],
              ),
            ),

            if (carregando)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (erro != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off, size: 56),
                    const SizedBox(height: 14),
                    Text(erro!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: carregarEventos,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              )
            else if (eventos.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Nenhum evento encontrado',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...eventos.map(itemEvento).toList(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
