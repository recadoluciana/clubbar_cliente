import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_storage.dart';

import '../models/auth_response.dart';
import '../models/evento.dart';
import '../models/loja.dart';
import '../models/categoria.dart';
import '../models/produto.dart';
import '../models/carteira_item.dart';
import '../models/evento_detalhe.dart';
import '../models/evento_lote.dart';

class ApiService {
  static const String baseUrl = 'https://bitbeer-production.up.railway.app';

  String _mensagemErroAmigavel(Object e) {
    final texto = e.toString().toLowerCase();

    if (texto.contains('socketexception') ||
        texto.contains('failed host lookup') ||
        texto.contains('connection refused')) {
      return 'Sem conexão com a internet ou servidor indisponível.';
    }

    if (texto.contains('timeout')) {
      return 'O servidor demorou para responder. Tente novamente.';
    }

    if (texto.contains('502') ||
        texto.contains('503') ||
        texto.contains('500')) {
      return 'Sistema em atualização. Tente novamente em instantes.';
    }

    return 'Não foi possível concluir a operação. Tente novamente.';
  }

  String _extrairMensagemHttp(http.Response response) {
    try {
      final data = jsonDecode(response.body);

      if (data is Map) {
        final detail = data['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }

        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }

        final mensagem = data['mensagem'];
        if (mensagem is String && mensagem.trim().isNotEmpty) {
          return mensagem;
        }
      }
    } catch (_) {}

    switch (response.statusCode) {
      case 500:
      case 502:
      case 503:
        return 'Sistema em atualização. Tente novamente em instantes.';
      case 401:
        return 'Sessão expirada. Faça login novamente.';
      case 404:
        return 'Recurso não encontrado.';
      default:
        return 'Erro na comunicação com o servidor.';
    }
  }

  String montarUrlCartaoWeb({
    required int clienteId,
    required int organizacaoId,
    required int lojaId,
  }) {
    return '$baseUrl/pagamentos/cartao-web'
        '?cliente_id=$clienteId'
        '&organizacao_id=$organizacaoId'
        '&loja_id=$lojaId';
  }

  Future<Map<String, String>> _headersAutenticado() async {
    final token = await AuthStorage().obterToken();

    if (token == null || token.isEmpty) {
      throw Exception('Usuário não autenticado');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

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

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
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

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
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

        return eventos.map((evento) {
          final banner = evento.bannerUrl.startsWith('http')
              ? evento.bannerUrl
              : '$baseUrl${evento.bannerUrl}';

          return Evento(
            id: evento.id,
            titulo: evento.titulo,
            data: evento.data,
            local: evento.local,
            bannerUrl: banner,
          );
        }).toList();
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
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

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  // ===============================
  // CATEGORIAS
  // ===============================
  Future<List<Categoria>> buscarCategoriasPorLoja(int lojaId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lojas/$lojaId/categorias'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        if (data is List) {
          return data.map((e) => Categoria.fromJson(e)).toList();
        }

        if (data is Map && data['items'] is List) {
          return (data['items'] as List)
              .map((e) => Categoria.fromJson(e))
              .toList();
        }

        return [];
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  // ===============================
  // PRODUTOS
  // ===============================
  Future<List<Produto>> buscarProdutosPorLoja(int lojaId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lojas/$lojaId/produtos'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        if (data is List) {
          return data.map((e) => Produto.fromJson(e)).toList();
        }

        if (data is Map && data['items'] is List) {
          return (data['items'] as List)
              .map((e) => Produto.fromJson(e))
              .toList();
        }

        return [];
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<void> adicionarAoCarrinho({
    required int clienteId,
    required int organizacaoId,
    required int lojaId,
    required int produtoId,
    int quantidade = 1,
    String? observacao,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/carrinho/adicionar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cliente_id': clienteId,
          'organizacao_id': organizacaoId,
          'loja_id': lojaId,
          'produto_id': produtoId,
          'quantidade': quantidade,
          'observacao': observacao,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<Map<String, dynamic>> buscarCarrinho({
    required int clienteId,
    required int organizacaoId,
    required int lojaId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/carrinho/itens?cliente_id=$clienteId&organizacao_id=$organizacaoId&loja_id=$lojaId',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        if (data is Map<String, dynamic>) {
          return data;
        }

        return {'carrinho_id': 0, 'itens': []};
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<void> removerItemCarrinho({
    required int carrinhoId,
    required int produtoId,
    required String observacao,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/carrinho/$carrinhoId/produto/$produtoId/um',
      ).replace(queryParameters: {'observacao': observacao});

      final response = await http.delete(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<Map<String, dynamic>> pagarCarrinhoPix({
    required int clienteId,
    required int organizacaoId,
    required int lojaId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pagamentos/pix'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cliente_id': clienteId,
          'organizacao_id': organizacaoId,
          'loja_id': lojaId,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
        throw Exception('Resposta inválida do pagamento PIX');
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<void> cadastrarCliente({
    required String nome,
    required String email,
    required String senha,
    String? telefone,
    String? cpf,
  }) async {
    try {
      final body = {
        'nmcliente': nome,
        'emailcliente': email,
        'senhahashcli': senha,
        'nrtelcliente': telefone?.trim().isEmpty == true ? null : telefone,
        'nrcpfcliente': cpf?.trim().isEmpty == true ? null : cpf,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register_cliente'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<void> esqueceuSenha({required String email}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/clientes/esqueci-senha'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'emailcliente': email}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<void> redefinirSenha({
    required String email,
    required String codigo,
    required String novaSenha,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/clientes/redefinir-senha'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'emailcliente': email,
          'codigo': codigo,
          'novasenha': novaSenha,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<void> alterarMinhaSenha({
    required String senhaAtual,
    required String novaSenha,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/clientes/me/senha'),
        headers: await _headersAutenticado(),
        body: jsonEncode({'senha_atual': senhaAtual, 'nova_senha': novaSenha}),
      );

      if (response.statusCode == 200) {
        return;
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<Map<String, dynamic>> buscarMeuPerfil() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/clientes/me'),
        headers: await _headersAutenticado(),
      );

      if (response.statusCode == 200) {
        final data = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : null;
        return Map<String, dynamic>.from(data);
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<void> atualizarMeuPerfil({
    required String nome,
    String? telefone,
    String? cpf,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/clientes/me'),
        headers: await _headersAutenticado(),
        body: jsonEncode({
          'nmcliente': nome,
          'nrtelcliente': telefone?.trim().isEmpty == true ? null : telefone,
          'nrcpfcliente': cpf?.trim().isEmpty == true ? null : cpf,
        }),
      );

      if (response.statusCode == 200) {
        return;
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<void> pagarComCartao({
    required int clienteId,
    required int organizacaoId,
    required int lojaId,
    required String encryptedCard,
    required String securityCode,
    required String tipoPagamento,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pagamentos/pagar-novo'),
        headers: await _headersAutenticado(),
        body: jsonEncode({
          'cliente_id': clienteId,
          'organizacao_id': organizacaoId,
          'loja_id': lojaId,
          'encrypted_card': encryptedCard,
          'security_code': securityCode,
          'payment_method': tipoPagamento,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<List<Map<String, dynamic>>> buscarCompras({
    required int clienteId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/compras?cliente_id=$clienteId&incluir_itens=true'),
        headers: await _headersAutenticado(),
      );

      if (response.statusCode == 200) {
        final data = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : null;

        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e)).toList();
        }

        return [];
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<List<Map<String, dynamic>>> buscarLojasComCarrinho({
    required int clienteId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/carrinho/lojas?cliente_id=$clienteId'),
        headers: await _headersAutenticado(),
      );

      if (response.statusCode == 200) {
        final data = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : null;

        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e)).toList();
        }

        return [];
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<int> buscarQuantidadeCarrinho({required int clienteId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/carrinho/qtde_itens_geral?cliente_id=$clienteId'),
        headers: await _headersAutenticado(),
      );

      if (response.statusCode == 200) {
        final data = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : null;
        return int.tryParse('${data['qt_total'] ?? 0}') ?? 0;
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<int> buscarQuantidadeCarteira({required int clienteId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/entregas/get_carteira_qt?cliente_id=$clienteId'),
        headers: await _headersAutenticado(),
      );

      if (response.statusCode == 200) {
        final data = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : null;
        return int.tryParse('${data['qt_total'] ?? 0}') ?? 0;
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<List<Map<String, dynamic>>> buscarPendentes({
    required int clienteId,
    int lojaId = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/entregas/pendentes?cliente_id=$clienteId&loja_id=$lojaId',
        ),
        headers: await _headersAutenticado(),
      );

      if (response.statusCode == 200) {
        final data = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : null;

        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e)).toList();
        }

        return [];
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<List<Evento>> buscarEventosPorLoja(int lojaId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/eventos/lojas/$lojaId/proximos'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        if (data is! List) {
          return [];
        }

        final eventos = data.map((e) => Evento.fromJson(e)).toList();

        return eventos.map((evento) {
          String banner = evento.bannerUrl.trim();

          if (banner.isNotEmpty && banner.startsWith('/')) {
            banner = '$baseUrl$banner';
          }

          if (banner.startsWith('http://')) {
            banner = banner.replaceFirst('http://', 'https://');
          }

          return Evento(
            id: evento.id,
            titulo: evento.titulo,
            data: evento.data,
            local: evento.local,
            bannerUrl: banner,
          );
        }).toList();
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<EventoDetalhe> buscarDetalheEvento(int eventoId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/eventos/$eventoId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final evento = EventoDetalhe.fromJson(data);

        String banner = evento.bannerUrl;
        if (banner.isNotEmpty && banner.startsWith('/')) {
          banner = '$baseUrl$banner';
        }
        if (banner.startsWith('http://')) {
          banner = banner.replaceFirst('http://', 'https://');
        }

        return EventoDetalhe(
          id: evento.id,
          titulo: evento.titulo,
          descricao: evento.descricao,
          dataInicio: evento.dataInicio,
          dataFim: evento.dataFim,
          local: evento.local,
          endereco: evento.endereco,
          bannerUrl: banner,
          status: evento.status,
          nomeLoja: evento.nomeLoja,
          nomeCidade: evento.nomeCidade,
        );
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }

  Future<List<EventoLote>> buscarLotesDoEvento(int eventoId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/eventos/$eventoId/lotes'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        if (data is! List) return [];

        return data
            .map((e) => EventoLote.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw Exception(_extrairMensagemHttp(response));
    } catch (e) {
      throw Exception(_mensagemErroAmigavel(e));
    }
  }
}
