class EventoDetalhe {
  final int id;
  final String titulo;
  final String descricao;
  final String dataInicio;
  final String dataFim;
  final String local;
  final String endereco;
  final String bannerUrl;
  final String status;
  final String nomeLoja;
  final String nomeCidade;

  EventoDetalhe({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.dataInicio,
    required this.dataFim,
    required this.local,
    required this.endereco,
    required this.bannerUrl,
    required this.status,
    required this.nomeLoja,
    required this.nomeCidade,
  });

  factory EventoDetalhe.fromJson(Map<String, dynamic> json) {
    return EventoDetalhe(
      id: _toInt(json['evento_id'] ?? json['id'] ?? 0),
      titulo: (json['nmtituloevento'] ?? 'Evento').toString(),
      descricao: (json['dsdescevento'] ?? '').toString(),
      dataInicio: (json['dtinicioevento'] ?? '').toString(),
      dataFim: (json['dtfimevento'] ?? '').toString(),
      local: (json['nmlocalevento'] ?? '').toString(),
      endereco: (json['dsendlocevento'] ?? '').toString(),
      bannerUrl: (json['urlbannerevento'] ?? '').toString().trim(),
      status: (json['statusevento'] ?? '').toString(),
      nomeLoja: (json['nmloja'] ?? '').toString(),
      nomeCidade: (json['nmcidade'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }
}
