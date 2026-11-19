import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../services/http_with_timeout.dart' as http;

import '../../services/api_service.dart';
import '../../widgets/clubbar_app_bar.dart';

class PoliticaCompraScreen extends StatefulWidget {
  final String tipo;
  final bool emModal;
  final ScrollController? scrollController;

  const PoliticaCompraScreen({
    super.key,
    this.tipo = 'INGRESSO',
    this.emModal = false,
    this.scrollController,
  });

  @override
  State<PoliticaCompraScreen> createState() => _PoliticaCompraScreenState();
}

class _PoliticaCompraScreenState extends State<PoliticaCompraScreen> {
  Map<String, dynamic>? _politica;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _erro = null;
      _politica = null;
    });
    try {
      final resposta = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/politicas/compra/vigente?tipo=${widget.tipo}',
        ),
      );
      if (resposta.statusCode != 200) {
        if (widget.tipo == 'PRIVACIDADE' && resposta.statusCode == 404) {
          if (mounted) {
            setState(
              () =>
                  _erro = 'A Política de Privacidade ainda não foi publicada.',
            );
          }
          return;
        }
        throw Exception('Não foi possível carregar a política de compra.');
      }
      if (!mounted) return;
      setState(
        () => _politica = Map<String, dynamic>.from(
          jsonDecode(resposta.body) as Map,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _erro = widget.tipo == 'PRIVACIDADE'
              ? 'Não foi possível carregar a Política de Privacidade agora.'
              : 'Não foi possível carregar a política de compra agora.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final conteudo = _politica == null && _erro == null
        ? const Center(child: CircularProgressIndicator())
        : _erro != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 48),
                  const SizedBox(height: 12),
                  Text(_erro!, textAlign: TextAlign.center),
                  TextButton.icon(
                    onPressed: _carregar,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          )
        : ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.emModal) ...[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Text(
                _politica!['titulo']?.toString() ?? 'Política de compra',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              SelectableText(
                _politica!['conteudo']?.toString() ?? '',
                textAlign: TextAlign.justify,
                style: const TextStyle(fontSize: 16, height: 1.55),
              ),
            ],
          );
    if (widget.emModal) return conteudo;
    return Scaffold(
      appBar: ClubbarAppBar(
        titulo: widget.tipo == 'PRIVACIDADE'
            ? 'Política de Privacidade'
            : 'Política Clubbar',
        mostrarVoltar: true,
        mostrarSessao: false,
        mostrarLogo: false,
        onVoltar: () => Navigator.pop(context),
      ),
      backgroundColor: const Color(0xFFF6F6F6),
      body: conteudo,
    );
  }
}

void mostrarPoliticaCompra(BuildContext context, {String tipo = 'INGRESSO'}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.74,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: PoliticaCompraScreen(
          tipo: tipo,
          emModal: true,
          scrollController: scrollController,
        ),
      ),
    ),
  );
}
