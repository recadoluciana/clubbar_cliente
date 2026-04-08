class Loja {
  final int id;
  final int organizacaoId;
  final String nome;
  final String bairro;
  final String horario;
  final String imagemUrl;
  final String instagram;

  Loja({
    required this.id,
    required this.organizacaoId,
    required this.nome,
    required this.bairro,
    required this.horario,
    required this.imagemUrl,
    required this.instagram,
  });

  static const String baseUrl = "https://bitbeer-production.up.railway.app";

  static String buildUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return "$baseUrl$path";
  }

  factory Loja.fromJson(Map<String, dynamic> json) {
    final path = (json['urllogoloja'] ?? '').toString();

    return Loja(
      id: _toInt(json['loja_id'] ?? 0),
      organizacaoId: _toInt(json['organizacao_id'] ?? 0),
      nome: (json['nmloja'] ?? '').toString(),
      bairro: (json['endloja'] ?? '').toString(),
      horario: (json['dshorarioloja'] ?? '').toString(),
      imagemUrl: buildUrl(path),
      instagram: (json['dsinstaloja'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }
}
