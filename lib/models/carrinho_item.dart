import '../services/api_service.dart';

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
      produtoId: _toInt(json['produto_id']),
      nome: (json['nmproduto'] ?? '').toString(),
      observacao: (json['observacao'] ?? json['dsobsitcar'] ?? '').toString(),
      fotoUrl: _buildUrl((json['urlfotoproduto'] ?? '').toString()),
      quantidade: _toInt(json['qt'], fallback: 1),
      precoOriginal: _toDouble(json['vrprecoprod']),
      precoFinal: _toDouble(json['vrprecofinal'] ?? json['vrprecoprod']),
      descontoAtivo: json['descontoativo'] == true,
      tipodesconto: (json['tipodesconto'] ?? 'NENHUM').toString(),
      vrdesconto: _toDouble(json['vrdesconto']),
    );
  }

  static String _buildUrl(String url) {
    final texto = url.trim();

    if (texto.isEmpty) return '';
    if (texto.startsWith('http')) return texto;

    return '${ApiService.baseUrl}${texto.startsWith('/') ? '' : '/'}$texto';
  }

  static int _toInt(dynamic valor, {int fallback = 0}) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? fallback;
  }

  static double _toDouble(dynamic valor) {
    if (valor is double) return valor;
    if (valor is int) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0;
  }
}
