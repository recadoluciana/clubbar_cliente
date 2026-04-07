class ItemCarrinho {
  final int produtoId;
  final String nome;
  final double preco;
  final int quantidade;
  final String fotoUrl;

  ItemCarrinho({
    required this.produtoId,
    required this.nome,
    required this.preco,
    required this.quantidade,
    required this.fotoUrl,
  });

  static const String baseUrl = 'https://bitbeer-production.up.railway.app';

  static String buildUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }

  factory ItemCarrinho.fromJson(Map<String, dynamic> json) {
    return ItemCarrinho(
      produtoId: _toInt(json['produto_id'] ?? 0),
      nome: (json['nmproduto'] ?? '').toString(),
      preco: _toDouble(json['vrprecoprod'] ?? 0),
      quantidade: _toInt(json['qtitcarrinho'] ?? 0),
      fotoUrl: buildUrl((json['urlfotoproduto'] ?? '').toString()),
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }

  static double _toDouble(dynamic valor) {
    if (valor is double) return valor;
    if (valor is int) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0;
  }
}
