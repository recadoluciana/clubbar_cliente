class Loja {
  final int id;
  final String nome;
  final String bairro;
  final String horario;
  final String imagemUrl;

  Loja({
    required this.id,
    required this.nome,
    required this.bairro,
    required this.horario,
    required this.imagemUrl,
  });

  factory Loja.fromJson(Map<String, dynamic> json) {
    return Loja(
      id: _toInt(json['loja_id'] ?? 0),
      nome: (json['nmloja'] ?? '').toString(),
      bairro: (json['endloja'] ?? '').toString(),
      horario: (json['dshorarioloja'] ?? '').toString(),
      imagemUrl: (json['urllogoloja'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }
}
