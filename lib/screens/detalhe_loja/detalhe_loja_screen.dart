import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/loja.dart';
import '../../widgets/cart_badge_action.dart';
import '../agenda/agenda_eventos_screen.dart';
import '../produtos_loja/produtos_loja_screen.dart';

class DetalheLojaScreen extends StatelessWidget {
  final Loja loja;

  const DetalheLojaScreen({super.key, required this.loja});

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o Instagram')),
      );
    }
  }

  // 🔥 IMAGEM COM ANIMAÇÃO + FULL WIDTH
  Widget _fotoFachada() {
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
        height: 200,
        width: double.infinity,
        child: loja.imagemUrl.isNotEmpty
            ? Image.network(loja.imagemUrl, fit: BoxFit.cover)
            : Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.image_not_supported, size: 48),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      // 🔥 TOP BAR PRETA
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        title: Text(
          loja.nome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CartBadgeAction(loja: loja),
          ),
        ],
      ),

      // 🔥 BODY SEM PADDING GLOBAL
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _fotoFachada(),

          // 🔥 CONTEÚDO COM PADDING
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loja.nome,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    const Icon(Icons.location_on_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loja.bairro.isEmpty
                            ? 'Endereço não informado'
                            : loja.bairro,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    const Icon(Icons.access_time),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loja.horario.isEmpty
                            ? 'Horário não informado'
                            : loja.horario,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

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

                const SizedBox(height: 20),

                _menuCard(
                  context: context,
                  titulo: 'Agenda',
                  icone: Icons.confirmation_number_rounded,
                  cor: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AgendaEventosScreen(loja: loja),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                _menuCard(
                  context: context,
                  titulo: 'Produtos',
                  icone: Icons.restaurant_menu_rounded,
                  cor: Colors.amber,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProdutosLojaScreen(loja: loja),
                      ),
                    );
                  },
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icone, color: cor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
