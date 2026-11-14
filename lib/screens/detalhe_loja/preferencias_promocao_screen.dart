import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/notificacoes_promocionais.dart';
import '../../services/main_navigation_controller.dart';
import '../../services/http_with_timeout.dart' as http;
import '../../widgets/clubbar_app_bar.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _testar() async {
    setState(() => _carregando = true);
    try {
      final token = await AuthStorage().obterToken();
      if (token == null || token.isEmpty) {
        throw Exception('Entre na sua conta para testar.');
      }
      await NotificacoesPromocionais.instance.testar(token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Teste enviado. Verifique as notificações do aparelho.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final mensagem = e.toString().replaceFirst('Exception: ', '');
        if (mensagem.contains('token APNs')) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Diagnóstico de notificações'),
              content: SelectableText(mensagem),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(mensagem)));
        }
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
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
              ),
              SwitchListTile(
                title: const Text('E-mails de promoções'),
                subtitle: const Text('Ofertas dos estabelecimentos.'),
                value: _email,
                onChanged: (v) => setState(() => _email = v),
              ),
              SwitchListTile(
                title: const Text('E-mails de novidades'),
                subtitle: const Text('Novidades e comunicados do Clubbar.'),
                value: _novidades,
                onChanged: (v) => setState(() => _novidades = v),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _salvar,
                child: const Text('Salvar preferências'),
              ),
              if (!kIsWeb)
                TextButton(
                  onPressed: _testar,
                  child: const Text('Testar notificação neste aparelho'),
                ),
            ],
          ),
  );
}
