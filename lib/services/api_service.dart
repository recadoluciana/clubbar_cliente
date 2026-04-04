import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/auth_response.dart';
import '../models/evento.dart';
import '../models/loja.dart';
import '../models/carteira_item.dart';

class ApiService {
  static const String baseUrl = 'https://bitbeer-production.up.railway.app';

  // ===============================
  // LOGIN
  // ===============================
  Future<AuthResponse> login({
    required String email,
    required String senha,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'senha': senha}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return AuthResponse.fromJson(data);
      }

      String mensagem = 'Erro ao fazer login';
      try {
        final body = jsonDecode(response.body);
        mensagem = body['detail']?.toString() ?? response.body;
      } catch (_) {
        mensagem = response.body;
      }

      throw Exception('HTTP ${response.statusCode}: $mensagem');
    } catch (e) {
      throw Exception('Falha de conexão no login: $e');
    }
  }

  // ===============================
  // LOJAS
  // ===============================
  Future<List<Loja>> buscarLojas() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lojas/listar_todas_ativas'),
        headers: {'Content-Type': 'application/json'},
      );

      print('LOJAS STATUS: ${response.statusCode}');
      print('LOJAS BODY: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        if (data is List) {
          return data.map((e) => Loja.fromJson(e)).toList();
        }

        if (data is Map && data['items'] is List) {
          return (data['items'] as List).map((e) => Loja.fromJson(e)).toList();
        }

        return [];
      }

      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception('Falha ao buscar lojas: $e');
    }
  }

  // ===============================
  // EVENTOS
  // ===============================
  Future<List<Evento>> buscarEventos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/eventos/proximos'),
        headers: {'Content-Type': 'application/json'},
      );

      print('EVENTOS STATUS: ${response.statusCode}');
      print('EVENTOS BODY: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        List<Evento> eventos = [];

        if (data is List) {
          eventos = data.map((e) => Evento.fromJson(e)).toList();
        } else if (data is Map && data['items'] is List) {
          eventos = (data['items'] as List)
              .map((e) => Evento.fromJson(e))
              .toList();
        }

        // 🔥 Corrige URL do banner
        return eventos.map((evento) {
          final banner = evento.bannerUrl.startsWith('http')
              ? evento.bannerUrl
              : '$baseUrl${evento.bannerUrl}';

          print('BANNER EVENTO: $banner');

          return Evento(
            id: evento.id,
            titulo: evento.titulo,
            data: evento.data,
            local: evento.local,
            bannerUrl: banner,
          );
        }).toList();
      }

      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception('Falha ao buscar eventos: $e');
    }
  }

  // ===============================
  // CARTEIRA
  // ===============================
  Future<List<CarteiraItem>> buscarCarteira({
    required int clienteId,
    required int lojaId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/entregas/pendentes?cliente_id=$clienteId&loja_id=$lojaId',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      print('CARTEIRA STATUS: ${response.statusCode}');
      print('CARTEIRA BODY: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        if (data is List) {
          return data.map((e) => CarteiraItem.fromJson(e)).toList();
        }

        if (data is Map && data['items'] is List) {
          return (data['items'] as List)
              .map((e) => CarteiraItem.fromJson(e))
              .toList();
        }

        return [];
      }

      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception('Falha ao buscar carteira: $e');
    }
  }
}
