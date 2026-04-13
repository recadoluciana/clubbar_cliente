import 'package:flutter/material.dart';
import '../../models/loja.dart';
import '../eventos_loja/eventos_loja_screen.dart';
import '../produtos_loja/produtos_loja_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class DetalheLojaScreen extends StatelessWidget {
  final Loja loja;

  const DetalheLojaScreen({super.key, required this.loja});

  void printLojaJson() {
    // Monta o JSON manualmente com os campos que você precisa
    debugPrint(
      '{'
      '"id": ${loja.id}, '
      '"nome": "${loja.nome}", '
      '"instagram": "${loja.instagram}"'
      '}',
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o Instagram')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Chama o print quando a tela é construída
    printLojaJson();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF111111),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  loja.imagemUrl.isNotEmpty
                      ? Image.network(
                          loja.imagemUrl,
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
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loja.bairro.isEmpty
                              ? 'Endereço não informado'
                              : loja.bairro,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loja.horario.isEmpty
                              ? 'Horário não informado'
                              : loja.horario,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => abrirInstagram(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.alternate_email, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loja.instagram,
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 15,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _menuCard(
                    context: context,
                    titulo: 'Ingressos',
                    icone: Icons.confirmation_number_rounded,
                    cor: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventosLojaScreen(loja: loja),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}
