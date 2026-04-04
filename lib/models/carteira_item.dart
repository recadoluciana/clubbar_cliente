class CarteiraItem {
  final int id;
  final int lojaId;
  final String tipo;
  final String titulo;
  final String descricao;
  final int quantidade;
  final String status;
  final String nomeLoja;
  final String nomeCliente;
  final String dataCriacao;
  final String dataExpiracao;
  final double valorUnitario;

  CarteiraItem({
    required this.id,
    required this.lojaId,
    required this.tipo,
    required this.titulo,
    required this.descricao,
    required this.quantidade,
    required this.status,
    required this.nomeLoja,
    required this.nomeCliente,
    required this.dataCriacao,
    required this.dataExpiracao,
    required this.valorUnitario,
  });

  factory CarteiraItem.fromJson(Map<String, dynamic> json) {
    return CarteiraItem(
      id: _toInt(json['itvenda_id'] ?? 0),
      lojaId: _toInt(json['loja_id'] ?? 0),
      tipo: 'PRODUTO',
      titulo: (json['nmproduto'] ?? 'Item').toString(),
      descricao: (json['dsobsitvenda'] ?? 'Disponível para retirada')
          .toString(),
      quantidade: _toInt(json['qtitvenda'] ?? 1),
      status: 'Disponível',
      nomeLoja: (json['nmloja'] ?? '').toString(),
      nomeCliente: (json['nmcliente'] ?? '').toString(),
      dataCriacao: (json['dtcriacao_fmt'] ?? '').toString(),
      dataExpiracao: (json['dtexpiraitvenda_fmt'] ?? '').toString(),
      valorUnitario: _toDouble(json['vrunititvenda'] ?? 0),
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }

  static double _toDouble(dynamic valor) {
    if (valor is double) return valor;
    if (valor is int) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0.0;
  }
}
