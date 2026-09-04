import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_app_bar.dart';

class ConteudoLojaScreen extends StatefulWidget {
  final Loja loja;

  const ConteudoLojaScreen({super.key, required this.loja});

  @override
  State<ConteudoLojaScreen> createState() => _ConteudoLojaScreenState();
}

class _ConteudoLojaScreenState extends State<ConteudoLojaScreen> {
  final _api = ApiService();
  bool _carregando = true;
  String? _erro;
  Map<String, dynamic> _conteudo = const {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  List<Map<String, dynamic>> _lista(String chave) =>
      (_conteudo[chave] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  String _url(dynamic valor) {
    final caminho = (valor ?? '').toString().trim();
    if (caminho.isEmpty || caminho.startsWith('http')) return caminho;
    return '${AppConfig.apiBaseUrl}${caminho.startsWith('/') ? '' : '/'}$caminho';
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final dados = await _api.buscarConteudoPublicoLoja(widget.loja.id);
      if (!mounted) return;
      setState(() => _conteudo = dados);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrirLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) AppSnackBar.erro(context, 'Não foi possível abrir o vídeo.');
    }
  }

  void _abrirFoto(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.sizeOf(context).height * .75,
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titulo(String texto, IconData icone) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icone, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(
          texto,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final descricao = (_conteudo['dsdetalhadaloja'] ?? '').toString().trim();
    final fotos = _lista('fotos');
    final videos = _lista('videos');
    final publicacoes = _lista('publicacoes');
    final vazio =
        descricao.isEmpty &&
        fotos.isEmpty &&
        videos.isEmpty &&
        publicacoes.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFC107), Color(0xFFFFECB3)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.loja.nome,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                const Text('Conteúdo do estabelecimento'),
              ],
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _erro != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_erro!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _carregar,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (vazio)
                          _card(
                            child: const Column(
                              children: [
                                Icon(Icons.photo_library_outlined, size: 48),
                                SizedBox(height: 10),
                                Text(
                                  'O estabelecimento ainda não publicou conteúdo.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        if (descricao.isNotEmpty)
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _titulo('Sobre', Icons.storefront_rounded),
                                Text(
                                  descricao,
                                  style: const TextStyle(height: 1.45),
                                ),
                              ],
                            ),
                          ),
                        if (fotos.isNotEmpty)
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _titulo(
                                  'Galeria de fotos',
                                  Icons.photo_library_rounded,
                                ),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: fotos.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 8,
                                      ),
                                  itemBuilder: (context, index) {
                                    final foto = fotos[index];
                                    final url = _url(foto['url']);
                                    return InkWell(
                                      onTap: () => _abrirFoto(url),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          url,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (
                                                context,
                                                error,
                                                stackTrace,
                                              ) => const ColoredBox(
                                                color: Color(0xFFEEEEEE),
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                ),
                                              ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        if (videos.isNotEmpty)
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _titulo('Vídeos', Icons.play_circle_rounded),
                                ...videos.map(
                                  (video) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.play_arrow_rounded),
                                    ),
                                    title: Text(
                                      '${video['titulo'] ?? 'Vídeo do estabelecimento'}',
                                    ),
                                    subtitle: Text(
                                      '${video['url'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: const Icon(
                                      Icons.open_in_new_rounded,
                                    ),
                                    onTap: () =>
                                        _abrirLink('${video['url'] ?? ''}'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (publicacoes.isNotEmpty)
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _titulo('Publicações', Icons.article_rounded),
                                ...publicacoes.map((publicacao) {
                                  final imagem = _url(publicacao['imagem']);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (imagem.isNotEmpty) ...[
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            child: Image.network(
                                              imagem,
                                              width: double.infinity,
                                              height: 180,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                        Text(
                                          '${publicacao['titulo'] ?? ''}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        if ('${publicacao['descricao'] ?? ''}'
                                            .trim()
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 5),
                                          Text('${publicacao['descricao']}'),
                                        ],
                                        if ('${publicacao['data_publicacao'] ?? ''}'
                                            .trim()
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            '${publicacao['data_publicacao']}',
                                            style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
