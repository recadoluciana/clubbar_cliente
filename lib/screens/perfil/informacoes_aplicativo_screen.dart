import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../widgets/app_version_text.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/clubbar_page_header.dart';

class InformacoesAplicativoScreen extends StatefulWidget {
  const InformacoesAplicativoScreen({super.key});

  @override
  State<InformacoesAplicativoScreen> createState() =>
      _InformacoesAplicativoScreenState();
}

class _InformacoesAplicativoScreenState
    extends State<InformacoesAplicativoScreen> {
  bool _carregando = true;
  bool _apiOnline = false;
  bool _bancoOnline = false;

  bool get _desenvolvimento =>
      AppConfig.isDev ||
      AppConfig.apiBaseUrl.contains('desenvolvimento') ||
      AppConfig.apiBaseUrl.contains('localhost');

  @override
  void initState() {
    super.initState();
    _consultar();
  }

  Future<void> _consultar() async {
    if (mounted) setState(() => _carregando = true);
    try {
      final resposta = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/health'))
          .timeout(const Duration(seconds: 8));
      final dados = resposta.statusCode == 200
          ? jsonDecode(resposta.body) as Map<String, dynamic>
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _apiOnline =
            resposta.statusCode == 200 &&
            (dados['api'] == null || dados['api'] == 'online');
        _bancoOnline = dados['database'] == 'online';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _apiOnline = false;
        _bancoOnline = false;
      });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Widget _linhaStatus(String titulo, bool online) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(child: Text(titulo, style: const TextStyle(fontSize: 16))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: online ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: online ? Colors.green.shade300 : Colors.red.shade300,
            ),
          ),
          child: Text(
            online ? 'Online' : 'Offline',
            style: TextStyle(
              color: online ? Colors.green.shade800 : Colors.red.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _card({required String titulo, required Widget child}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F6F6),
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: Column(
      children: [
        const ClubbarPageHeader(
          titulo: 'Sobre o aplicativo',
          subtitulo: 'Versão e situação do acesso',
          mostrarAvatar: false,
          pesoTitulo: FontWeight.normal,
          pesoSubtitulo: FontWeight.normal,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _card(
                titulo: 'Clubbar',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppVersionText(
                      prefix: 'Versão instalada: ',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ambiente: ${_desenvolvimento ? 'Desenvolvimento' : 'Produção'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                titulo: 'Situação do acesso',
                child: _carregando
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Column(
                        children: [
                          _linhaStatus('API do Clubbar', _apiOnline),
                          _linhaStatus('Banco de dados', _bancoOnline),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _consultar,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Verificar novamente'),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
