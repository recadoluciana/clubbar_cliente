import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/http_with_timeout.dart' as http;
import '../../widgets/clubbar_app_bar.dart';

class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({super.key});

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  late Future<List<dynamic>> _notificacoes = _carregar();

  Future<List<dynamic>> _carregar() async {
    final sessao = await AuthStorage().obterToken();
    if (sessao == null || sessao.isEmpty) {
      throw Exception('Entre na sua conta para consultar suas notificações.');
    }
    final resposta = await http.get(
      Uri.parse(
        '${ApiService.baseUrl}/clientes/me/dispositivos-promocao/notificacoes',
      ),
      headers: {'Authorization': 'Bearer $sessao'},
    );
    if (resposta.statusCode != 200) {
      throw Exception('Não foi possível carregar suas notificações.');
    }
    return jsonDecode(resposta.body) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ClubbarAppBar(
      titulo: 'Minhas notificações',
      mostrarVoltar: true,
      mostrarSessao: false,
    ),
    body: FutureBuilder<List<dynamic>>(
      future: _notificacoes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Não foi possível carregar suas notificações.'),
                TextButton(
                  onPressed: () => setState(() => _notificacoes = _carregar()),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }
        final itens = snapshot.data ?? [];
        if (itens.isEmpty) {
          return const Center(child: Text('Nenhuma notificação encontrada.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: itens.length,
          itemBuilder: (context, index) {
            final item = itens[index] as Map;
            final data = DateTime.tryParse('${item['criado_em'] ?? ''}');
            final dataFormatada = data == null
                ? 'Não disponível'
                : DateFormat('dd/MM/yyyy HH:mm').format(data);
            return Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: Text('${item['titulo']}'),
                subtitle: Text(
                  '${item['estabelecimento']}\n${item['mensagem']}\nData de envio: $dataFormatada',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    ),
  );
}
