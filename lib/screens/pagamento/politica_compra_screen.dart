import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../../widgets/clubbar_app_bar.dart';

class PoliticaCompraScreen extends StatefulWidget {
  const PoliticaCompraScreen({super.key});

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
        Uri.parse('${ApiService.baseUrl}/politicas/compra/vigente'),
      );
      if (resposta.statusCode != 200) {
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
          () => _erro = 'Não foi possível carregar a política de compra agora.',
        );
      }
    }
  }

  String _data(dynamic valor) {
    final data = DateTime.tryParse(valor?.toString() ?? '');
    if (data == null) return '';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ClubbarAppBar(
      mostrarVoltar: true,
      onVoltar: () => Navigator.pop(context),
    ),
    backgroundColor: const Color(0xFFF6F6F6),
    body: _politica == null && _erro == null
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
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                _politica!['titulo']?.toString() ?? 'Política de Compra',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Versão ${_politica!['versao'] ?? ''}${_data(_politica!['dtiniciovigencia']).isEmpty ? '' : ' • Vigente desde ${_data(_politica!['dtiniciovigencia'])}'}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              SelectableText(
                _politica!['conteudo']?.toString() ?? '',
                style: const TextStyle(fontSize: 16, height: 1.55),
              ),
            ],
          ),
  );
}
