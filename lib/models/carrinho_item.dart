class ItemCarrinho {
  final int produtoId;
  final String nome;
  final String observacao;
  final String fotoUrl;
  final int quantidade;

  final double precoOriginal;
  final double precoFinal;
  final bool descontoAtivo;
  final String tipodesconto;
  final double vrdesconto;

  ItemCarrinho({
    required this.produtoId,
    required this.nome,
    required this.observacao,
    required this.fotoUrl,
    required this.quantidade,
    required this.precoOriginal,
    required this.precoFinal,
    required this.descontoAtivo,
    required this.tipodesconto,
    required this.vrdesconto,
  });

  factory ItemCarrinho.fromJson(Map<String, dynamic> json) {
    return ItemCarrinho(
      produtoId: json['produto_id'] ?? 0,
      nome: json['nmproduto'] ?? '',
      observacao: json['observacao'] ?? '',
      fotoUrl: (json['urlfotoproduto'] ?? '').toString(),
      quantidade: json['qt'] ?? 1,
      precoOriginal: (json['vrprecoprod'] ?? 0).toDouble(),
      precoFinal: (json['vrprecofinal'] ?? json['vrprecoprod'] ?? 0).toDouble(),
      descontoAtivo: json['descontoativo'] ?? false,
      tipodesconto: (json['tipodesconto'] ?? 'NENHUM').toString(),
      vrdesconto: (json['vrdesconto'] ?? 0).toDouble(),
    );
  }
}
