import 'package:flutter/material.dart';

import '../../models/evento.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../detalhe_evento/detalhe_evento_screen.dart';
import '../pagamento/politica_compra_screen.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../services/main_navigation_controller.dart';

class AgendaEventosScreen extends StatefulWidget {
  final Loja loja;

  const AgendaEventosScreen({super.key, required this.loja});

  @override
  State<AgendaEventosScreen> createState() => _AgendaEventosScreenState();
}

class _AgendaEventosScreenState extends State<AgendaEventosScreen> {
  static const _tamanhoMiniaturaEvento = 76.0;
  final apiService = ApiService();

  bool carregando = true;
  String? erro;
  List<Evento> eventos = [];
  String pesquisa = '';

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

      if (!mounted) return;
      setState(() {
        eventos = lista;
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '');
        carregando = false;
      });
    }
  }

  String formatarCabecalhoData(String valor) {
    return DateFormatters.dataCompleta(valor);
  }

  String _normalizarBusca(String texto) {
    return texto
        .toLowerCase()
        .replaceAll(RegExp('[áàâãä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôõö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll('ç', 'c');
  }

  bool _correspondePesquisa(Evento evento) {
    final termo = _normalizarBusca(pesquisa.trim());
    if (termo.isEmpty) return true;

    final conteudo = [
      evento.titulo,
      formatarCabecalhoData(evento.data),
      evento.data,
      ...evento.atracoes.map((atracao) => atracao.nome),
    ].join(' ');
    return _normalizarBusca(conteudo).contains(termo);
  }

  List<String> _estilosDoEvento(Evento evento) {
    final estilos =
        evento.atracoes
            .expand((atracao) => atracao.estilos)
            .where((estilo) => estilo.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return estilos;
  }

  Widget _badge({
    required IconData icone,
    required String texto,
    required Color cor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 13, color: cor),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 116),
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgesEvento(Evento evento) {
    final estilos = _estilosDoEvento(evento);
    final atracoes = evento.atracoes
        .where((atracao) => atracao.nome.trim().isNotEmpty)
        .toList();
    if (estilos.isEmpty && atracoes.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        ...estilos
            .take(3)
            .map(
              (estilo) => _badge(
                icone: Icons.music_note_rounded,
                texto: estilo,
                cor: const Color(0xFF2E7D32),
              ),
            ),
        ...atracoes
            .take(3)
            .map(
              (atracao) => _badge(
                icone: Icons.mic_rounded,
                texto: atracao.nome,
                cor: const Color(0xFF1565C0),
              ),
            ),
      ],
    );
  }

  Widget imagemEvento(String url) {
    Widget moldura(Widget child) => Container(
      width: _tamanhoMiniaturaEvento,
      height: _tamanhoMiniaturaEvento,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      alignment: Alignment.center,
      child: child,
    );

    if (url.trim().isEmpty) {
      return moldura(
        Container(
          color: Colors.grey.shade100,
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported),
        ),
      );
    }

    return moldura(
      SizedBox.expand(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported),
          ),
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
            MainNavigationController.abrirTela(
              DetalheEventoScreen(eventoId: evento.id, loja: widget.loja),
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            formatarCabecalhoData(evento.data),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (evento.jaIniciado)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Evento já iniciado',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
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
                      _badgesEvento(evento),
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
    );
  }

  Widget _rodapePoliticaIngresso() {
    final cor = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PoliticaCompraScreen(tipo: 'INGRESSO'),
              ),
            ),
            icon: const Icon(Icons.policy_outlined, size: 18),
            label: const Text('Política de compra de ingresso'),
            style: TextButton.styleFrom(
              foregroundColor: cor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventosFiltrados = eventos.where(_correspondePesquisa).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: ClubbarAppBar(
        titulo: 'Agenda - ${widget.loja.nome}',
        iconeTitulo: Icons.confirmation_number_rounded,
        corIconeTitulo: Colors.blue,
        mostrarVoltar: true,
        mostrarSessao: false,
        actions: [
          IconButton(
            tooltip: 'Atualizar agenda',
            onPressed: carregarEventos,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        onVoltar: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
            return;
          }
          MainNavigationController.fecharTelaInterna();
        },
      ),
      bottomNavigationBar: _rodapePoliticaIngresso(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              onChanged: (valor) => setState(() => pesquisa = valor),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'evento, atração, dia da semana',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search_rounded, size: 21),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: carregarEventos,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                children: [
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
                  else if (eventosFiltrados.isEmpty)
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
                          Text(
                            pesquisa.trim().isEmpty
                                ? 'Nenhum evento encontrado'
                                : 'Nenhum evento encontrado para esta busca',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...eventosFiltrados.map(itemEvento),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
