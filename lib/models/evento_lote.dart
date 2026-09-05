class EventoLote {
  final int loteId;
  final int eventoId;
  final String nome;
  final String nomeSetor;
  final int numeroLote;
  final String tipoIngresso;
  final double preco;
  final int qtTotal;
  final int qtVendida;
  final bool semLimite;
  final String status;
  final String dataInicioVenda;
  final String dataFimVenda;

  EventoLote({
    required this.loteId,
    required this.eventoId,
    required this.nome,
    this.nomeSetor = '',
    this.numeroLote = 1,
    this.tipoIngresso = 'UNICO',
    required this.preco,
    required this.qtTotal,
    required this.qtVendida,
    required this.semLimite,
    required this.status,
    required this.dataInicioVenda,
    required this.dataFimVenda,
  });

  int get qtDisponivel {
    final disponivel = qtTotal - qtVendida;
    return disponivel < 0 ? 0 : disponivel;
  }

  bool podeComprarEm(DateTime agora) {
    final statusNormalizado = status.trim().toUpperCase();
    if (statusNormalizado != 'ATIVO') return false;
    if (!semLimite && qtDisponivel <= 0) return false;

    final inicio = DateTime.tryParse(dataInicioVenda)?.toLocal();
    final fim = DateTime.tryParse(dataFimVenda)?.toLocal();
    if (inicio != null && agora.isBefore(inicio)) return false;
    if (fim != null && agora.isAfter(fim)) return false;
    return true;
  }

  String situacaoVendaEm(DateTime agora) {
    final statusNormalizado = status.trim().toUpperCase();
    if (statusNormalizado == 'ESGOTADO' || (!semLimite && qtDisponivel <= 0)) {
      return 'Esgotado';
    }
    if (statusNormalizado == 'INATIVO') return 'Indisponível';
    if (statusNormalizado == 'ENCERRADO') return 'Vendas encerradas';

    final inicio = DateTime.tryParse(dataInicioVenda)?.toLocal();
    final fim = DateTime.tryParse(dataFimVenda)?.toLocal();
    if (inicio != null && agora.isBefore(inicio)) return 'Em breve';
    if (fim != null && agora.isAfter(fim)) return 'Vendas encerradas';
    return statusNormalizado == 'ATIVO' ? 'Disponível' : 'Indisponível';
  }

  factory EventoLote.fromJson(Map<String, dynamic> json) {
    return EventoLote(
      loteId: _toInt(json['lote_id'] ?? 0),
      eventoId: _toInt(json['evento_id'] ?? 0),
      nome: (json['nmlote'] ?? '').toString(),
      nomeSetor: (json['nmsetor'] ?? '').toString(),
      numeroLote: _toInt(json['nrlote'] ?? 1),
      tipoIngresso: (json['tipoingresso'] ?? 'UNICO').toString(),
      preco: _toDouble(json['vrprecolote'] ?? 0),
      qtTotal: _toInt(json['qttotallote'] ?? 0),
      qtVendida: _toInt(json['qtvendidalote'] ?? 0),
      semLimite: json['qttotallote'] == null,
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
