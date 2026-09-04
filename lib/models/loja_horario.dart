class LojaHorario {
  final int? id;
  final int diaSemana;
  final bool fechado;
  final String? horaAbertura;
  final String? horaFechamento;
  final bool fechaDiaSeguinte;

  const LojaHorario({
    required this.id,
    required this.diaSemana,
    required this.fechado,
    this.horaAbertura,
    this.horaFechamento,
    this.fechaDiaSeguinte = false,
  });

  factory LojaHorario.fromJson(Map<String, dynamic> json) {
    return LojaHorario(
      id: _toNullableInt(json['lojahorario_id'] ?? json['loja_horario_id']),
      diaSemana: _toInt(json['diasemana'] ?? json['dia_semana']),
      fechado: _toBool(json['fechado']),
      horaAbertura: _hora(json['horaabertura'] ?? json['hora_abertura']),
      horaFechamento: _hora(json['horafechamento'] ?? json['hora_fechamento']),
      fechaDiaSeguinte: _toBool(
        json['fechadiaseguinte'] ?? json['fecha_dia_seguinte'],
      ),
    );
  }

  String get nomeDia {
    const nomes = {
      1: 'Segunda-feira',
      2: 'Terça-feira',
      3: 'Quarta-feira',
      4: 'Quinta-feira',
      5: 'Sexta-feira',
      6: 'Sábado',
      7: 'Domingo',
    };
    return nomes[diaSemana] ?? 'Dia não identificado';
  }

  static String? _hora(dynamic valor) {
    final texto = valor?.toString().trim() ?? '';
    if (texto.isEmpty) return null;
    final partes = texto.split(':');
    if (partes.length < 2) return texto;
    return '${partes[0].padLeft(2, '0')}:${partes[1].padLeft(2, '0')}';
  }

  static int _toInt(dynamic valor) {
    if (valor is num) return valor.toInt();
    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  static int? _toNullableInt(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor.toString());
  }

  static bool _toBool(dynamic valor) {
    if (valor is bool) return valor;
    if (valor is num) return valor != 0;
    return const {
      'S',
      'SIM',
      'TRUE',
      '1',
    }.contains(valor?.toString().trim().toUpperCase());
  }
}
