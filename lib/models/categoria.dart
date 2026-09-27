class Categoria {
  final int id;
  final String nome;
  final String? icone;

  Categoria({required this.id, required this.nome, this.icone});

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: _toInt(json['categoria_id'] ?? json['id'] ?? 0),
      nome: (json['nmcategoria'] ?? json['nome'] ?? 'Categoria').toString(),
      icone: json['dsicone']?.toString(),
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }
}
