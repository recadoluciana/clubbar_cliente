import 'package:clubbar_cliente/config/app_config.dart';

class Loja {
  final int id;
  final int organizacaoId;
  final String nome;
  final String endereco;
  final String bairro;
  final String cidade;
  final String imagemUrl;
  final String fachadaUrl;
  final String instagram;
  final double vrtaxaprod;
  final double vrtaxaing;
  final double vrtaxaminimaingresso;
  final String dsestiloloja;
  final List<String> estilosMusicais;
  final String nrtelloja;
  final String sgEstado;
  final String numero;
  final bool aberto24x7;
  final DateTime? dataCriacao;

  Loja({
    required this.id,
    required this.organizacaoId,
    required this.nome,
    required this.endereco,
    required this.bairro,
    required this.cidade,
    required this.imagemUrl,
    this.fachadaUrl = '',
    required this.instagram,
    required this.vrtaxaprod,
    required this.vrtaxaing,
    this.vrtaxaminimaingresso = 0,
    required this.dsestiloloja,
    this.estilosMusicais = const [],
    required this.nrtelloja,
    required this.sgEstado,
    this.numero = '',
    this.aberto24x7 = false,
    this.dataCriacao,
  });

  static final String baseUrl =
      AppConfig.apiBaseUrl; // Use the apiBaseUrl from AppConfig

  static String buildUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return "$baseUrl$path";
  }

  factory Loja.fromJson(Map<String, dynamic> json) {
    final path = (json['urllogoloja'] ?? '').toString();
    final fachadaPath = (json['urlfachadaloja'] ?? '').toString();

    final estilos = (json['estilos'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => (item['nmestilomusical'] ?? '').toString().trim())
        .where((nome) => nome.isNotEmpty)
        .toList(growable: false);

    return Loja(
      id: _toInt(json['loja_id'] ?? 0),
      organizacaoId: _toInt(json['organizacao_id'] ?? 0),
      nome: (json['nmloja'] ?? '').toString(),
      endereco: (json['endloja'] ?? '').toString(),
      bairro: (json['dsbairroloja'] ?? '').toString(),
      cidade: (json['nmcidade'] ?? '').toString(),
      imagemUrl: buildUrl(path),
      fachadaUrl: buildUrl(fachadaPath),
      instagram: (json['dsinstaloja'] ?? '').toString(),
      vrtaxaprod: double.tryParse(json['vrtaxaprod']?.toString() ?? '0') ?? 0,
      vrtaxaing: double.tryParse(json['vrtaxaing']?.toString() ?? '0') ?? 0,
      vrtaxaminimaingresso: double.tryParse(json['vrtaxaminimaingresso']?.toString() ?? '0') ?? 0,
      dsestiloloja: estilos.isNotEmpty
          ? estilos.join(', ')
          : (json['dsestiloloja'] ?? '').toString(),
      estilosMusicais: estilos,
      nrtelloja: (json['nrtelloja'] ?? '').toString(),
      sgEstado: (json['sgestado'] ?? '').toString(),
      numero: (json['nrendeloja'] ?? '').toString(),
      aberto24x7: _toBool(json['aberto24x7']),
      dataCriacao: DateTime.tryParse((json['dtcriacao'] ?? '').toString()),
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }

  static bool _toBool(dynamic valor) {
    if (valor is bool) return valor;
    if (valor is num) return valor != 0;
    return const {
      'S',
      'SIM',
      'TRUE',
      '1',
    }.contains(valor?.toString().trim().toUpperCase());
  }
}
