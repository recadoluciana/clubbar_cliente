import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/http_with_timeout.dart' as http;
import '../../widgets/clubbar_app_bar.dart';

class PreferenciasPromocaoScreen extends StatefulWidget {
  const PreferenciasPromocaoScreen({super.key, required this.loja});
  final Loja loja;

  @override
  State<PreferenciasPromocaoScreen> createState() =>
      _PreferenciasPromocaoScreenState();
}

class _PreferenciasPromocaoScreenState
    extends State<PreferenciasPromocaoScreen> {
  bool _push = false;
  bool _whatsapp = false;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthStorage().obterToken();
    if (token == null || token.isEmpty) {
      throw Exception('Entre na sua conta para escolher suas preferências.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri get _url => Uri.parse(
    '${ApiService.baseUrl}/clientes/me/promocoes/${widget.loja.id}',
  );

  Future<void> _carregar() async {
    try {
      final response = await http.get(_url, headers: await _headers());
      if (response.statusCode != 200) {
        throw Exception('Não foi possível carregar suas preferências.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _push = data['push'] == true;
        _whatsapp = data['whatsapp'] == true;
        _carregando = false;
        _erro = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');
        _carregando = false;
      });
    }
  }

  Future<void> _salvar() async {
    setState(() => _carregando = true);
    try {
      final response = await http.put(
        _url,
        headers: await _headers(),
        body: jsonEncode({'push': _push, 'whatsapp': _whatsapp}),
      );
      if (response.statusCode != 200) {
        var mensagem = 'Não foi possível salvar suas preferências.';
        try {
          final dados = jsonDecode(response.body);
          if (dados is Map && dados['detail'] is String) {
            mensagem = dados['detail'] as String;
          }
        } catch (_) {}
        throw Exception(mensagem);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Preferências salvas.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ClubbarAppBar(
      titulo: 'Promoções',
      mostrarVoltar: true,
      mostrarSessao: false,
      mostrarCarrinho: false,
    ),
    body: _carregando
        ? const Center(child: CircularProgressIndicator())
        : _erro != null
        ? Center(child: Text(_erro!))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Promoções de ${widget.loja.nome}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
              'Escolha como deseja receber promoções deste estabelecimento. Você pode mudar de ideia quando quiser. O envio de promoções ainda está em preparação.',
              ),
              SwitchListTile(
                title: const Text('Notificações no aplicativo'),
                value: _push,
                onChanged: (v) => setState(() => _push = v),
              ),
              SwitchListTile(
                title: const Text('WhatsApp'),
                subtitle: const Text('No número cadastrado no seu perfil'),
                value: _whatsapp,
                onChanged: (v) => setState(() => _whatsapp = v),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _salvar,
                child: const Text('Salvar preferências'),
              ),
            ],
          ),
  );
}
