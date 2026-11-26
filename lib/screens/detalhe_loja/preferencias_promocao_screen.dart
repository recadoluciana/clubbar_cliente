import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../utils/app_snackbar.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/notificacoes_promocionais.dart';
import '../../services/main_navigation_controller.dart';
import '../../services/http_with_timeout.dart' as http;
import '../../widgets/clubbar_app_bar.dart';
import 'notificacoes_screen.dart';

class PreferenciasPromocaoScreen extends StatefulWidget {
  const PreferenciasPromocaoScreen({super.key});

  @override
  State<PreferenciasPromocaoScreen> createState() =>
      _PreferenciasPromocaoScreenState();
}

class _PreferenciasPromocaoScreenState
    extends State<PreferenciasPromocaoScreen> {
  bool _push = false;
  bool _email = false;
  bool _novidades = false;
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

  Uri get _url =>
      Uri.parse('${ApiService.baseUrl}/clientes/me/preferencias-notificacao');

  Future<void> _carregar() async {
    try {
      final response = await http.get(_url, headers: await _headers());
      if (response.statusCode != 200) {
        throw Exception('Não foi possível carregar suas preferências.');
      }
      final Object? data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        throw Exception(
          'As preferências de ofertas ainda não estão disponíveis. Tente novamente mais tarde.',
        );
      }
      if (data is! Map<String, dynamic>) {
        throw Exception(
          'As preferências de ofertas ainda não estão disponíveis. Tente novamente mais tarde.',
        );
      }
      final preferencias = data;
      if (!mounted) return;
      setState(() {
        _push = preferencias['push'] == true;
        _email = preferencias['email'] == true;
        _novidades = preferencias['novidades'] == true;
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
      if (_push && !kIsWeb) {
        final token = await AuthStorage().obterToken();
        if (token == null || token.isEmpty) {
          throw Exception(
            'Entre na sua conta para escolher suas preferências.',
          );
        }
        await NotificacoesPromocionais.instance.ativar(
          token,
          solicitarPermissao: true,
        );
      }
      final response = await http.put(
        _url,
        headers: await _headers(),
        body: jsonEncode({
          'push': _push,
          'email': _email,
          'novidades': _novidades,
        }),
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
      MainNavigationController.fecharTelaInterna();
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ClubbarAppBar(
      actions: [
        IconButton(
          tooltip: 'Minhas notificações',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const NotificacoesScreen())),
        ),
      ],
      titulo: 'Notificações/e-mails',
      tituloAlinhadoEsquerda: true,
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
                'Preferências de notificações',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Escolha como deseja receber promoções e novidades do Clubbar. Você pode desmarcar quando quiser.',
              ),
              SwitchListTile(
                title: const Text('Notificações no aplicativo'),
                value: _push,
                onChanged: (v) => setState(() => _push = v),
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.green,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.red,
              ),
              SwitchListTile(
                title: const Text('E-mails de promoções'),
                subtitle: const Text('Ofertas dos estabelecimentos.'),
                value: _email,
                onChanged: (v) => setState(() => _email = v),
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.green,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.red,
              ),
              SwitchListTile(
                title: const Text('E-mails de novidades'),
                subtitle: const Text('Novidades e comunicados do Clubbar.'),
                value: _novidades,
                onChanged: (v) => setState(() => _novidades = v),
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.green,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.red,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _salvar,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Salvar preferências'),
              ),
            ],
          ),
  );
}
