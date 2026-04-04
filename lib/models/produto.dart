class Produto {
  final int id;
  final int categoriaId;
  final String nome;
  final String descricao;
  final double preco;
  final String categoriaNome;
  final String imagemUrl;

  Produto({
    required this.id,
    required this.categoriaId,
    required this.nome,
    required this.descricao,
    required this.preco,
    required this.categoriaNome,
    required this.imagemUrl,
  });

  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      id: _toInt(json['produto_id'] ?? json['id'] ?? 0),
      categoriaId: _toInt(json['categoria_id'] ?? 0),
      nome: (json['nmproduto'] ?? 'Produto').toString(),
      descricao: (json['dsproduto'] ?? '').toString(),
      preco: _toDouble(json['vrprecoprod'] ?? 0),
      categoriaNome: (json['nmcategoria'] ?? '').toString(),
      imagemUrl: (json['urlfotoproduto'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }

  static double _toDouble(dynamic valor) {
    if (valor is double) return valor;
    if (valor is int) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0.0;
  }
}
