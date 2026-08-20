import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiStatusIndicator extends StatefulWidget {
  const ApiStatusIndicator({super.key});

  @override
  State<ApiStatusIndicator> createState() => _ApiStatusIndicatorState();
}

class _ApiStatusIndicatorState extends State<ApiStatusIndicator> {
  Timer? _timer;
  bool _online = false;
  bool _bancoOnline = false;
  bool _consultando = true;
  String _ambiente = '?';

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
        _ambiente = (dados['environment'] ?? '?').toString().toUpperCase();
        _consultando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _online = false;
        _bancoOnline = false;
        _ambiente = '?';
        _consultando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cor = _consultando || (_online && !_bancoOnline)
        ? Colors.amber
        : _online
        ? Colors.greenAccent.shade400
        : Colors.redAccent;
    final api = _consultando ? '...' : (_online ? 'ON' : 'OFF');

    return Tooltip(
      message:
          'API: ${_online ? 'online' : 'offline'} | Banco: ${_bancoOnline ? 'online' : 'offline'} | Ambiente: $_ambiente',
      child: InkWell(
        onTap: _consultar,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                'API $api\nDB $_ambiente',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
