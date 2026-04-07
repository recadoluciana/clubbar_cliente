import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/auth_response.dart';
import '../models/evento.dart';
import '../models/loja.dart';
import '../models/categoria.dart';
import '../models/produto.dart';
import '../models/carteira_item.dart';
import '../models/carrinho_item.dart';

class ApiService {
  static const String baseUrl = 'https://bitbeer-production.up.railway.app';

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

  Future<List<Categoria>> buscarCategoriasPorLoja(int lojaId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lojas/$lojaId/categorias'),
        headers: {'Content-Type': 'application/json'},
      );

      print('CATEGORIAS STATUS: ${response.statusCode}');
      print('CATEGORIAS BODY: ${response.body}');

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

      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception('Falha ao buscar categorias: $e');
    }
  }

  Future<List<Produto>> buscarProdutosPorLoja(int lojaId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lojas/$lojaId/produtos'),
        headers: {'Content-Type': 'application/json'},
      );

      print('PRODUTOS STATUS: ${response.statusCode}');
      print('PRODUTOS BODY: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        List<Produto> produtos = [];

        if (data is List) {
          produtos = data.map((e) => Produto.fromJson(e)).toList();
        } else if (data is Map && data['items'] is List) {
          produtos = (data['items'] as List)
              .map((e) => Produto.fromJson(e))
              .toList();
        }

        return produtos.map((produto) {
          String foto = produto.imagemUrl.trim();

          if (foto.isEmpty) {
            return Produto(
              id: produto.id,
              categoriaId: produto.categoriaId,
              nome: produto.nome,
              descricao: produto.descricao,
              preco: produto.preco,
              categoriaNome: produto.categoriaNome,
              imagemUrl: '',
            );
          }

          if (foto.startsWith('/')) {
            foto = '$baseUrl$foto';
          }

          if (foto.startsWith('http://')) {
            foto = foto.replaceFirst('http://', 'https://');
          }

          return Produto(
            id: produto.id,
            categoriaId: produto.categoriaId,
            nome: produto.nome,
            descricao: produto.descricao,
            preco: produto.preco,
            categoriaNome: produto.categoriaNome,
            imagemUrl: foto,
          );
        }).toList();
      }

      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception('Falha ao buscar produtos: $e');
    }
  }

  Future<void> adicionarAoCarrinho({
    required int clienteId,
    required int organizacaoId,
    required int lojaId,
    required int produtoId,
    int quantidade = 1,
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
        }),
      );

      print('ADD CARRINHO STATUS: ${response.statusCode}');
      print('ADD CARRINHO BODY: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      String mensagem = 'Não foi possível adicionar ao carrinho';
      try {
        final body = jsonDecode(response.body);
        mensagem = body['detail']?.toString() ?? response.body;
      } catch (_) {
        mensagem = response.body;
      }

      throw Exception(mensagem);
    } catch (e) {
      throw Exception('Falha ao adicionar ao carrinho: $e');
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

      print('CARRINHO STATUS: ${response.statusCode}');
      print('CARRINHO BODY: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        if (data is Map<String, dynamic>) {
          return data;
        }

        return {'carrinho_id': 0, 'itens': []};
      }

      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception('Falha ao buscar carrinho: $e');
    }
  }

  Future<void> removerItemCarrinho({
    required int carrinhoId,
    required int produtoId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/carrinho/$carrinhoId/produto/$produtoId/um'),
        headers: {'Content-Type': 'application/json'},
      );

      print('REMOVER ITEM STATUS: ${response.statusCode}');
      print('REMOVER ITEM BODY: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      String mensagem = 'Não foi possível remover o item do carrinho';
      try {
        final body = jsonDecode(response.body);
        mensagem = body['detail']?.toString() ?? response.body;
      } catch (_) {
        mensagem = response.body;
      }

      throw Exception(mensagem);
    } catch (e) {
      throw Exception('Falha ao remover item do carrinho: $e');
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

      print('PIX STATUS: ${response.statusCode}');
      print('PIX BODY: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
        throw Exception('Resposta inválida do pagamento PIX');
      }

      String mensagem = 'Não foi possível gerar o PIX';
      try {
        final body = jsonDecode(response.body);
        mensagem = body['detail']?.toString() ?? response.body;
      } catch (_) {
        mensagem = response.body;
      }

      throw Exception(mensagem);
    } catch (e) {
      throw Exception('Falha ao iniciar pagamento PIX: $e');
    }
  }

  Future<void> cadastrarCliente({
    required String nome,
    required String email,
    required String senha,
    String? telefone,
    String? cpf,
  }) async {
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

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erro ao cadastrar cliente');
    }
  }

  Future<void> esqueceuSenha({required String email}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/clientes/esqueci-senha'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'emailcliente': email}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Não foi possível enviar o código');
    }
  }

  Future<void> redefinirSenha({
    required String email,
    required String codigo,
    required String novaSenha,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/clientes/redefinir-senha'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'emailcliente': email,
        'codigo': codigo,
        'novasenha': novaSenha,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Não foi possível redefinir a senha');
    }
  }
}
