class EventoLote {
  final int loteId;
  final int eventoId;
  final String nome;
  final double preco;
  final int qtTotal;
  final int qtVendida;
  final String status;
  final String dataInicioVenda;
  final String dataFimVenda;

  EventoLote({
    required this.loteId,
    required this.eventoId,
    required this.nome,
    required this.preco,
    required this.qtTotal,
    required this.qtVendida,
    required this.status,
    required this.dataInicioVenda,
    required this.dataFimVenda,
  });

  int get qtDisponivel {
    final disponivel = qtTotal - qtVendida;
    return disponivel < 0 ? 0 : disponivel;
  }

  factory EventoLote.fromJson(Map<String, dynamic> json) {
    return EventoLote(
      loteId: _toInt(json['lote_id'] ?? 0),
      eventoId: _toInt(json['evento_id'] ?? 0),
      nome: (json['nmlote'] ?? '').toString(),
      preco: _toDouble(json['vrprecolote'] ?? 0),
      qtTotal: _toInt(json['qttotallote'] ?? 0),
      qtVendida: _toInt(json['qtvendidalote'] ?? 0),
      status: (json['statuslote'] ?? 'ATIVO').toString(),
      dataInicioVenda: (json['dtiniciovenda'] ?? '').toString(),
      dataFimVenda: (json['dtfimvenda'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }

  static double _toDouble(dynamic valor) {
    if (valor is double) return valor;
    if (valor is int) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0;
  }
}
