import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiStatusIndicator extends StatefulWidget {
  final String versao;

  const ApiStatusIndicator({super.key, required this.versao});

  @override
  State<ApiStatusIndicator> createState() => _ApiStatusIndicatorState();
}

class _ApiStatusIndicatorState extends State<ApiStatusIndicator> {
  Timer? _timer;
  bool _online = false;
  bool _bancoOnline = false;

  bool get _ambienteDev =>
      AppConfig.isDev ||
      AppConfig.apiBaseUrl.contains('desenvolvimento') ||
      AppConfig.apiBaseUrl.contains('localhost');

  @override
  void initState() {
    super.initState();
    _consultar();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _consultar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _consultar() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/health'))
          .timeout(const Duration(seconds: 5));
      final dados = response.statusCode == 200
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _online =
            response.statusCode == 200 &&
            (dados['api'] == null || dados['api'] == 'online');
        _bancoOnline = dados['database'] == 'online';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _online = false;
        _bancoOnline = false;
      });
    }
  }

  Future<void> _mostrarDetalhes() async {
    await _consultar();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.developer_mode_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Ambiente'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API: ${_online ? 'online' : 'offline'}'),
            const SizedBox(height: 8),
            Text('Banco: ${_bancoOnline ? 'online' : 'offline'}'),
            const SizedBox(height: 8),
            Text('Ambiente: ${_ambienteDev ? 'Desenvolvimento' : 'Produção'}'),
            const SizedBox(height: 8),
            Text('Versão: ${widget.versao}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Sobre o aplicativo',
        child: InkWell(
          onTap: _mostrarDetalhes,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 25,
                  height: 25,
                  child: Image.asset(
                    'assets/images/corujao.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'Cora',
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
