import 'package:clubbar_cliente/config/app_config.dart';

class Produto {
  final int produtoId;
  final int? cardapioItemId;
  final int organizacaoId;
  final int lojaId;
  final int categoriaId;
  final String nmproduto;
  final String dsproduto;
  final double vrprecoprod;
  final String sitproduto;
  final String nmcategoria;
  final String? urlfotoproduto;

  final String tipodesconto;
  final double vrdesconto;
  final String? dtinidesconto;
  final String? dtfimdesconto;
  final double vrprecofinal;
  final bool descontoativo;
  final bool? cortesiaDisponivel;
  final int? cortesiasResgatadas;
  final int? cortesiasRestantes;
  final String nmloja;
  final int quantidadeVendida;

  Produto({
    required this.produtoId,
    this.cardapioItemId,
    required this.organizacaoId,
    required this.lojaId,
    required this.categoriaId,
    required this.nmproduto,
    required this.dsproduto,
    required this.vrprecoprod,
    required this.sitproduto,
    required this.nmcategoria,
    required this.urlfotoproduto,
    required this.tipodesconto,
    required this.vrdesconto,
    required this.dtinidesconto,
    required this.dtfimdesconto,
    required this.vrprecofinal,
    required this.descontoativo,
    this.cortesiaDisponivel,
    this.cortesiasResgatadas,
    this.cortesiasRestantes,
    this.nmloja = '',
    this.quantidadeVendida = 0,
  });

  static final String baseUrl =
      AppConfig.apiBaseUrl; // Use the apiBaseUrl from AppConfig

  static String? buildUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$baseUrl${path.startsWith('/') ? '' : '/'}$path';
  }

  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      produtoId: _toInt(json['produto_id']),
      cardapioItemId: int.tryParse((json['cardapioitem_id'] ?? '').toString()),
      organizacaoId: _toInt(json['organizacao_id']),
      lojaId: _toInt(json['loja_id']),
      categoriaId: _toInt(json['categoria_id']),
      nmproduto: json['nmproduto'] ?? '',
      dsproduto: json['dsproduto'] ?? '',
      vrprecoprod: _toDouble(json['vrprecoprod']),
      sitproduto: json['sitproduto'] ?? '',
      nmcategoria: json['nmcategoria'] ?? '',
      urlfotoproduto: buildUrl(json['urlfotoproduto']),
      tipodesconto: json['tipodesconto'] ?? 'NENHUM',
      vrdesconto: _toDouble(json['vrdesconto']),
      dtinidesconto: json['dtinidesconto'],
      dtfimdesconto: json['dtfimdesconto'],
      vrprecofinal: _toDouble(json['vrprecofinal'] ?? json['vrprecoprod']),
      descontoativo: _toBool(json['descontoativo']),
      cortesiaDisponivel: json.containsKey('cortesia_disponivel')
          ? _toBool(json['cortesia_disponivel'])
          : null,
      cortesiasResgatadas: int.tryParse(
        (json['qtcortesiasresgatadas'] ?? '').toString(),
      ),
      cortesiasRestantes: int.tryParse(
        (json['qtcortesiasrestantes'] ?? '').toString(),
      ),
      nmloja: (json['nmloja'] ?? '').toString(),
      quantidadeVendida:
          int.tryParse((json['quantidade_vendida'] ?? 0).toString()) ?? 0,
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic valor) {
    if (valor is double) return valor;
    if (valor is int) return valor.toDouble();
    return double.tryParse(valor?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  static bool _toBool(dynamic valor) {
    if (valor is bool) return valor;
    if (valor is num) return valor != 0;
    return valor?.toString().trim().toLowerCase() == 'true' ||
        valor?.toString().trim() == '1';
  }
}
