class CarrinhoItem {
  final int id;
  final int produtoId;
  final String nome;
  final String descricao;
  final int quantidade;
  final double precoUnitario;
  final String imagemUrl;

  CarrinhoItem({
    required this.id,
    required this.produtoId,
    required this.nome,
    required this.descricao,
    required this.quantidade,
    required this.precoUnitario,
    required this.imagemUrl,
  });

  double get subtotal => quantidade * precoUnitario;

  factory CarrinhoItem.fromJson(Map<String, dynamic> json) {
    return CarrinhoItem(
      id: _toInt(json['itcarrinho_id'] ?? json['id'] ?? 0),
      produtoId: _toInt(json['produto_id'] ?? 0),
      nome: (json['nmproduto'] ?? 'Produto').toString(),
      descricao: (json['obs'] ?? '').toString(),
      quantidade: _toInt(json['qt'] ?? 1),
      precoUnitario: _toDouble(json['vrprecoprod'] ?? 0),
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
