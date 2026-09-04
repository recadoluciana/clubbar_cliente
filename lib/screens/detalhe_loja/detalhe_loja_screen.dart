import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/loja.dart';
import '../../models/loja_horario.dart';
import '../../services/api_service.dart';
import '../agenda/agenda_eventos_screen.dart';
import '../produtos_loja/produtos_loja_screen.dart';
import '../../services/main_navigation_controller.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../utils/app_snackbar.dart';

class DetalheLojaScreen extends StatefulWidget {
  final Loja loja;

  const DetalheLojaScreen({super.key, required this.loja});

  @override
  State<DetalheLojaScreen> createState() => _DetalheLojaScreenState();
}

class _DetalheLojaScreenState extends State<DetalheLojaScreen> {
  final ApiService _apiService = ApiService();
  late final Future<List<LojaHorario>> _horariosFuture;

  Loja get loja => widget.loja;

  @override
  void initState() {
    super.initState();
    _horariosFuture = _apiService.buscarHorariosLoja(loja.id);
  }

  Future<void> abrirInstagram(BuildContext context) async {
    final handle = loja.instagram.replaceAll('@', '').trim();

    if (handle.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Instagram não informado')));
      return;
    }

    final uriApp = Uri.parse('instagram://user?username=$handle');
    final uriWeb = Uri.parse('https://instagram.com/$handle');

    if (await canLaunchUrl(uriApp)) {
      await launchUrl(uriApp, mode: LaunchMode.externalApplication);
      return;
    }

    if (await canLaunchUrl(uriWeb)) {
      await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
      return;
    }

    if (context.mounted) {
      AppSnackBar.erro(context, 'Não foi possível abrir o Instagram.');
    }
  }

  Widget _imagemRede({
    required String url,
    required BoxFit fit,
    required IconData fallbackIcon,
  }) {
    if (url.trim().isEmpty) {
      return Container(
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: Icon(fallbackIcon, size: 48, color: Colors.grey.shade600),
      );
    }

    return Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => Container(
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: Icon(fallbackIcon, size: 48, color: Colors.grey.shade600),
      ),
    );
  }

  Widget _cabecalhoImagens() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700),
      tween: Tween<double>(begin: 0.95, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Opacity(
          opacity: scale,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: SizedBox(
        height: 260,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(
              bottom: 46,
              child: _imagemRede(
                url: loja.fachadaUrl,
                fit: BoxFit.cover,
                fallbackIcon: Icons.storefront_rounded,
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                width: 98,
                height: 98,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .18),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _imagemRede(
                    url: loja.imagemUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.local_bar_rounded,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _enderecoCompleto() {
    String endereco = '';

    if (loja.endereco.trim().isNotEmpty) {
      endereco += loja.endereco.trim();
    }

    if (loja.numero.trim().isNotEmpty) {
      endereco += endereco.isEmpty
          ? loja.numero.trim()
          : ', ${loja.numero.trim()}';
    }

    if (loja.bairro.trim().isNotEmpty) {
      if (endereco.isNotEmpty) endereco += ' - ';
      endereco += loja.bairro.trim();
    }

    final cidadeEstado = [
      if (loja.cidade.trim().isNotEmpty) loja.cidade.trim(),
      if (loja.sgEstado.trim().isNotEmpty) loja.sgEstado.trim(),
    ].join(' - ');

    if (cidadeEstado.isNotEmpty) {
      endereco += '\n$cidadeEstado';
    }

    if (endereco.isEmpty) {
      return 'Endereço não informado';
    }

    return endereco;
  }

  String _telefoneFormatado() {
    var numeros = loja.nrtelloja.replaceAll(RegExp(r'\D'), '');
    if (numeros.length > 11 && numeros.startsWith('55')) {
      numeros = numeros.substring(2);
    }
    if (numeros.length == 11) {
      return '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 7)}-${numeros.substring(7)}';
    }
    if (numeros.length == 10) {
      return '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 6)}-${numeros.substring(6)}';
    }
    return loja.nrtelloja.trim();
  }

  String _resumoHorario(List<LojaHorario> horarios) {
    if (loja.aberto24x7) {
      return 'Aberto 24 horas, todos os dias da semana';
    }
    final dias = horarios.where((item) => !item.fechado).length;
    if (dias == 0) return 'Horário de atendimento não definido';
    return 'Horário definido para $dias ${dias == 1 ? 'dia' : 'dias'} da semana';
  }

  Future<void> _mostrarHorarios(
    BuildContext context,
    List<LojaHorario> horarios,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Horários de ${loja.nome}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              if (loja.aberto24x7)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.schedule_rounded, color: Colors.blue),
                  title: Text('Aberto 24 horas'),
                  subtitle: Text('Todos os dias da semana'),
                )
              else
                ...horarios.map(
                  (item) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.nomeDia),
                    trailing: Text(
                      item.fechado
                          ? 'Fechado'
                          : '${item.horaAbertura ?? '--:--'} às '
                                '${item.horaFechamento ?? '--:--'}'
                                '${item.fechaDiaSeguinte ? ' (+1 dia)' : ''}',
                      style: TextStyle(
                        color: item.fechado
                            ? Colors.grey
                            : Colors.blue.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _horarioAtendimento(BuildContext context) {
    return FutureBuilder<List<LojaHorario>>(
      future: _horariosFuture,
      builder: (context, snapshot) {
        final horarios = snapshot.data ?? const <LojaHorario>[];
        final carregando = snapshot.connectionState == ConnectionState.waiting;
        final possuiInformacao =
            loja.aberto24x7 || horarios.any((item) => !item.fechado);

        return Row(
          children: [
            const Icon(Icons.access_time),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                carregando
                    ? 'Carregando horários...'
                    : _resumoHorario(horarios),
              ),
            ),
            if (!carregando && possuiInformacao)
              IconButton(
                tooltip: 'Ver horários de atendimento',
                onPressed: () => _mostrarHorarios(context, horarios),
                icon: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.blue,
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: ClubbarAppBar(mostrarVoltar: true),

      // 🔥 BODY SEM PADDING GLOBAL
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _cabecalhoImagens(),

          // 🔥 CONTEÚDO COM PADDING
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    loja.nome,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                if (loja.dsestiloloja.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.interests_outlined,
                        size: 20,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          loja.dsestiloloja.trim(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),

                Row(
                  children: [
                    const Icon(Icons.location_on_outlined),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_enderecoCompleto())),
                  ],
                ),

                if (loja.nrtelloja.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_telefoneFormatado())),
                    ],
                  ),
                ],

                const SizedBox(height: 8),

                _horarioAtendimento(context),

                const SizedBox(height: 8),

                InkWell(
                  onTap: () => abrirInstagram(context),
                  child: Row(
                    children: [
                      const Icon(Icons.alternate_email),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loja.instagram.isEmpty
                              ? 'Instagram não informado'
                              : loja.instagram,
                          style: TextStyle(
                            color: loja.instagram.isEmpty
                                ? Colors.grey
                                : Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: _menuCard(
                        context: context,
                        titulo: 'Agenda\nIngressos',
                        icone: Icons.confirmation_number_rounded,
                        cor: Colors.blue,
                        onTap: () {
                          MainNavigationController.abrirTela(
                            AgendaEventosScreen(loja: loja),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _menuCard(
                        context: context,
                        titulo: 'Cardápio\nProdutos',
                        icone: Icons.restaurant_menu_rounded,
                        cor: Colors.amber,
                        onTap: () {
                          MainNavigationController.abrirTela(
                            ProdutosLojaScreen(loja: loja),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuCard({
    required BuildContext context,
    required String titulo,
    required IconData icone,
    required Color cor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 145,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icone, color: cor, size: 30),
              ),

              Text(
                titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
