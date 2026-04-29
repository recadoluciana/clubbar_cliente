class Evento {
  final int id;
  final String titulo;
  final String data;
  final String local;
  final String bannerUrl;

  // 🔥 NOVOS CAMPOS IMPORTANTES
  final int lojaId;
  final int organizacaoId;
  final String nomeLoja;

  Evento({
    required this.id,
    required this.titulo,
    required this.data,
    required this.local,
    required this.bannerUrl,
    required this.lojaId,
    required this.organizacaoId,
    required this.nomeLoja,
  });

  factory Evento.fromJson(Map<String, dynamic> json) {
    return Evento(
      id: _toInt(json['evento_id'] ?? json['id'] ?? 0),
      titulo: (json['nmtituloevento'] ?? 'Evento').toString(),
      data: (json['dtinicioevento'] ?? json['data'] ?? '').toString(),
      local: (json['nmlocalevento'] ?? json['nmloja'] ?? '').toString(),
      bannerUrl: (json['urlbannerevento'] ?? '').toString().trim(),

      // 🔥 AQUI ESTÁ A CORREÇÃO PRINCIPAL
      lojaId: _toInt(json['loja_id'] ?? 0),
      organizacaoId: _toInt(json['organizacao_id'] ?? 0),
      nomeLoja: (json['nmloja'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }
}
