import 'package:flutter_test/flutter_test.dart';
import 'package:clubbar_cliente/models/loja_horario.dart';

void main() {
  LojaHorario horario(
    int dia,
    String inicio,
    String fim, {
    bool seguinte = false,
  }) => LojaHorario(
    id: null,
    diaSemana: dia,
    fechado: false,
    horaAbertura: inicio,
    horaFechamento: fim,
    fechaDiaSeguinte: seguinte,
  );

  test('respeita abertura, fechamento e dias sem atendimento', () {
    final horarios = [horario(1, '09:00', '18:00')];
    expect(lojaAbertaAgora(horarios, DateTime(2026, 11, 2, 9)), true);
    expect(lojaAbertaAgora(horarios, DateTime(2026, 11, 2, 18)), false);
    expect(lojaAbertaAgora(horarios, DateTime(2026, 11, 3, 10)), false);
  });

  test('considera horário que atravessa a meia-noite e a semana', () {
    final horarios = [horario(7, '22:00', '02:00', seguinte: true)];
    expect(lojaAbertaAgora(horarios, DateTime(2026, 11, 1, 23)), true);
    expect(lojaAbertaAgora(horarios, DateTime(2026, 11, 2, 1)), true);
    expect(lojaAbertaAgora(horarios, DateTime(2026, 11, 2, 2)), false);
  });

  test('não informa fechado quando não há horários válidos', () {
    expect(lojaAbertaAgora([], DateTime(2026, 11, 2)), isNull);
    expect(
      lojaAbertaAgora([horario(1, '', '18:00')], DateTime(2026, 11, 2)),
      isNull,
    );
  });
}
