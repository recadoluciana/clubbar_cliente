class Loja {
  final int id;
  final int organizacaoId;
  final String nome;
  final String bairro;
  final String horario;
  final String imagemUrl;

  Loja({
    required this.id,
    required this.organizacaoId,
    required this.nome,
    required this.bairro,
    required this.horario,
    required this.imagemUrl,
  });

  static const String baseUrl = "https://bitbeer-production.up.railway.app";

  factory Loja.fromJson(Map<String, dynamic> json) {
    String path = (json['urllogoloja'] ?? '').toString();

    String urlFinal = '';

    if (path.isNotEmpty) {
      if (path.startsWith('http')) {
        urlFinal = path;
      } else {
        urlFinal = "$baseUrl$path";
      }
    }

    return Loja(
      id: _toInt(json['loja_id'] ?? 0),
      organizacaoId: _toInt(json['organizacao_id'] ?? 0),
      nome: (json['nmloja'] ?? '').toString(),
      bairro: (json['endloja'] ?? '').toString(),
      horario: (json['dshorarioloja'] ?? '').toString(),
      imagemUrl: urlFinal,
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }
}
