class EventoDetalhe {
  final int id;
  final String titulo;
  final String descricao;
  final String politicaCancelamento;
  final String politicaReembolso;
  final String politicaCashback;
  final String dataInicio;
  final String dataFim;
  final String local;
  final String endereco;
  final String numeroEndereco;
  final String bairro;
  final String bannerUrl;
  final String status;
  final String nomeLoja;
  final String nomeCidade;
  final String sgEstado;
  final List<AtracaoEventoDetalhe> atracoes;

  EventoDetalhe({
    required this.id,
    required this.titulo,
    required this.descricao,
    this.politicaCancelamento = '',
    this.politicaReembolso = '',
    this.politicaCashback = '',
    required this.dataInicio,
    required this.dataFim,
    required this.local,
    required this.endereco,
    this.numeroEndereco = '',
    required this.bairro,
    required this.bannerUrl,
    required this.status,
    required this.nomeLoja,
    required this.nomeCidade,
    required this.sgEstado,
    required this.atracoes,
  });

  factory EventoDetalhe.fromJson(Map<String, dynamic> json) {
    return EventoDetalhe(
      id: _toInt(json['evento_id'] ?? json['id'] ?? 0),
      titulo: (json['nmtituloevento'] ?? 'Evento').toString(),
      descricao: (json['dsdescevento'] ?? '').toString(),
      politicaCancelamento: (json['dspoliticacancelamento'] ?? '').toString(),
      politicaReembolso: (json['dspoliticareembolso'] ?? '').toString(),
      politicaCashback: (json['dspoliticacashback'] ?? '').toString(),
      dataInicio: (json['dtinicioevento'] ?? '').toString(),
      dataFim: (json['dtfimevento'] ?? '').toString(),
      local: (json['nmlocalevento'] ?? '').toString(),
      endereco: (json['dsendlocevento'] ?? '').toString(),
      numeroEndereco: (json['nrendlocevento'] ?? '').toString(),
      bairro: (json['dsbairroloja'] ?? '').toString(),
      bannerUrl: (json['urlbannerevento'] ?? '').toString().trim(),
      status: (json['statusevento'] ?? '').toString(),
      nomeLoja: (json['nmloja'] ?? '').toString(),
      nomeCidade: (json['nmcidade'] ?? '').toString(),
      sgEstado: (json['sgestado'] ?? '').toString(),
      atracoes: (json['atracoes'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                AtracaoEventoDetalhe.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }
}

class AtracaoEventoDetalhe {
  final int id;
  final String nome;
  final String estilo;
  final String descricao;
  final String bannerUrl;
  final String inicio;
  final String fim;

  const AtracaoEventoDetalhe({
    required this.id,
    required this.nome,
    required this.estilo,
    required this.descricao,
    required this.bannerUrl,
    required this.inicio,
    required this.fim,
  });

  factory AtracaoEventoDetalhe.fromJson(Map<String, dynamic> json) {
    return AtracaoEventoDetalhe(
      id: EventoDetalhe._toInt(json['atracao_id'] ?? 0),
      nome: (json['nmatracao'] ?? 'Atração').toString(),
      estilo: (json['dsestilomusical'] ?? '').toString(),
      descricao: (json['dsatracao'] ?? '').toString(),
      bannerUrl: (json['urlbanneratracao'] ?? '').toString(),
      inicio: (json['dtinicioatracao'] ?? '').toString(),
      fim: (json['dtfimatracao'] ?? '').toString(),
    );
  }
}
