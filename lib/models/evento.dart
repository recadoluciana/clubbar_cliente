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
  final String logoLojaUrl;
  final int totalVendasLoja;

  Evento({
    required this.id,
    required this.titulo,
    required this.data,
    required this.local,
    required this.bannerUrl,
    required this.lojaId,
    required this.organizacaoId,
    required this.nomeLoja,
    this.logoLojaUrl = '',
    this.totalVendasLoja = 0,
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
      logoLojaUrl: (json['urllogoloja'] ?? '').toString().trim(),
      totalVendasLoja: _toInt(json['total_vendas_loja'] ?? 0),
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }
}
