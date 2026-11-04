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

/// Retorna null quando não há horários suficientes para determinar a situação.
bool? lojaAbertaAgora(List<LojaHorario> horarios, DateTime agora) {
  if (!horarios.any((horario) => !horario.fechado)) return null;

  int? minutos(String? hora) {
    final partes = hora?.split(':');
    if (partes == null || partes.length < 2) return null;
    final h = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }

  final minutoAtual = agora.hour * 60 + agora.minute;
  final diaAnterior = agora.weekday == 1 ? 7 : agora.weekday - 1;
  var incompleto = false;
  for (final horario in horarios) {
    if (horario.fechado ||
        (horario.diaSemana != agora.weekday &&
            horario.diaSemana != diaAnterior)) {
      continue;
    }
    final abertura = minutos(horario.horaAbertura);
    final fechamento = minutos(horario.horaFechamento);
    if (abertura == null || fechamento == null) {
      incompleto = true;
      continue;
    }
    if (horario.fechaDiaSeguinte) {
      if ((horario.diaSemana == agora.weekday && minutoAtual >= abertura) ||
          (horario.diaSemana == diaAnterior && minutoAtual < fechamento)) {
        return true;
      }
    } else if (horario.diaSemana == agora.weekday &&
        minutoAtual >= abertura &&
        minutoAtual < fechamento) {
      return true;
    }
  }
  return incompleto ? null : false;
}
