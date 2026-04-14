class Produto {
  final int produtoId;
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

  Produto({
    required this.produtoId,
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
  });

  static const String baseUrl = "https://bitbeer-production.up.railway.app";

  static String? buildUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$baseUrl$path';
  }

  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      produtoId: json['produto_id'] ?? 0,
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
    );
  }
}
