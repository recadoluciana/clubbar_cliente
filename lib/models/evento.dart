class Evento {
  final int id;
  final String titulo;
  final String data;
  final String local;
  final String bannerUrl;

  Evento({
    required this.id,
    required this.titulo,
    required this.data,
    required this.local,
    required this.bannerUrl,
  });

  factory Evento.fromJson(Map<String, dynamic> json) {
    return Evento(
      id: _toInt(json['evento_id'] ?? json['id'] ?? 0),
      titulo: (json['nmtituloevento'] ?? 'Evento').toString(),
      data: (json['dtinicioevento'] ?? '').toString(),
      local: (json['nmlocalevento'] ?? json['nmloja'] ?? '').toString(),
      bannerUrl: (json['urlbannerevento'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }
}
