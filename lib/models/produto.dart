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
    this.nmloja = '',
    this.quantidadeVendida = 0,
  });

  static final String baseUrl =
      AppConfig.apiBaseUrl; // Use the apiBaseUrl from AppConfig

  static String? buildUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$baseUrl$path';
  }

  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      produtoId: json['produto_id'] ?? 0,
      cardapioItemId: int.tryParse((json['cardapioitem_id'] ?? '').toString()),
      organizacaoId: json['organizacao_id'] ?? 0,
      lojaId: json['loja_id'] ?? 0,
      categoriaId: json['categoria_id'] ?? 0,
      nmproduto: json['nmproduto'] ?? '',
      dsproduto: json['dsproduto'] ?? '',
      vrprecoprod: (json['vrprecoprod'] ?? 0).toDouble(),
      sitproduto: json['sitproduto'] ?? '',
      nmcategoria: json['nmcategoria'] ?? '',
      urlfotoproduto: buildUrl(json['urlfotoproduto']),
      tipodesconto: json['tipodesconto'] ?? 'NENHUM',
      vrdesconto: (json['vrdesconto'] ?? 0).toDouble(),
      dtinidesconto: json['dtinidesconto'],
      dtfimdesconto: json['dtfimdesconto'],
      vrprecofinal: (json['vrprecofinal'] ?? json['vrprecoprod'] ?? 0)
          .toDouble(),
      descontoativo: json['descontoativo'] ?? false,
      nmloja: (json['nmloja'] ?? '').toString(),
      quantidadeVendida:
          int.tryParse((json['quantidade_vendida'] ?? 0).toString()) ?? 0,
    );
  }
}
