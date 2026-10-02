class EventoLote {
  final int loteId;
  final int loteGlobalId;
  final int lotePrecoId;
  final int eventoId;
  final String nome;
  final String nomeSetor;
  final String descricaoSetor;
  final int numeroLote;
  final String tipoIngresso;
  final bool exigeComprovante;
  final bool aplicaCotaLegal;
  final int cotaLegal;
  final int qtVendidaCotaLegal;
  final int qtReservadaCotaLegal;
  final double preco;
  final int qtTotal;
  final int qtVendida;
  final int qtReservada;
  final int? qtCapacidadeRestante;
  final bool semLimite;
  final String status;
  final String dataInicioVenda;
  final String dataFimVenda;

  EventoLote({
    required this.loteId,
    this.loteGlobalId = 0,
    this.lotePrecoId = 0,
    required this.eventoId,
    required this.nome,
    this.nomeSetor = '',
    this.descricaoSetor = '',
    this.numeroLote = 1,
    this.tipoIngresso = 'UNICO',
    this.exigeComprovante = false,
    this.aplicaCotaLegal = false,
    this.cotaLegal = 0,
    this.qtVendidaCotaLegal = 0,
    this.qtReservadaCotaLegal = 0,
    required this.preco,
    required this.qtTotal,
    required this.qtVendida,
    this.qtReservada = 0,
    this.qtCapacidadeRestante,
    required this.semLimite,
    required this.status,
    required this.dataInicioVenda,
    required this.dataFimVenda,
  });

  int get qtDisponivel {
    final disponivel =
        qtCapacidadeRestante ?? (qtTotal - qtVendida - qtReservada);
    return disponivel < 0 ? 0 : disponivel;
  }

  int get qtDisponivelCotaLegal {
    final disponivel = cotaLegal - qtVendidaCotaLegal - qtReservadaCotaLegal;
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
    if (statusNormalizado == 'AGUARDANDO') return 'Em breve';
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
      loteGlobalId: _toInt(json['loteglobal_id'] ?? 0),
      lotePrecoId: _toInt(json['lotepreco_id'] ?? 0),
      eventoId: _toInt(json['evento_id'] ?? 0),
      nome: (json['nmlote'] ?? '').toString(),
      nomeSetor: (json['nmsetor'] ?? '').toString(),
      descricaoSetor: (json['dssetor'] ?? '').toString(),
      numeroLote: _toInt(json['nrlote'] ?? 1),
      tipoIngresso: (json['tipoingresso'] ?? 'UNICO').toString(),
      exigeComprovante: json['exigecomprovante'] == true,
      aplicaCotaLegal: json['aplicacotalegal'] == true,
      cotaLegal: _toInt(json['cotalegal'] ?? 0),
      qtVendidaCotaLegal: _toInt(json['qtvendidacotalegal'] ?? 0),
      qtReservadaCotaLegal: _toInt(json['qtreservadacotalegal'] ?? 0),
      preco: _toDouble(json['vrprecolote'] ?? 0),
      qtTotal: _toInt(json['qttotallote'] ?? 0),
      qtVendida: _toInt(json['qtvendidalote'] ?? 0),
      semLimite: json['usarcapacidaderestante'] == true,
      qtReservada: _toInt(json['qtreservadalote'] ?? 0),
      qtCapacidadeRestante: json['qtdisponivel'] == null
          ? null
          : _toInt(json['qtdisponivel']),
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
