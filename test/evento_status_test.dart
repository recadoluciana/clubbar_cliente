import 'package:clubbar_cliente/models/evento.dart';
import 'package:clubbar_cliente/models/evento_detalhe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identifica evento da agenda que já começou', () {
    final evento = Evento.fromJson({
      'evento_id': 1,
      'dtinicioevento': DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
    });

    expect(evento.jaIniciado, isTrue);
  });

  test('não marca detalhe de evento futuro como iniciado', () {
    final evento = EventoDetalhe.fromJson({
      'evento_id': 1,
      'dtinicioevento': DateTime.now()
          .add(const Duration(minutes: 1))
          .toIso8601String(),
    });

    expect(evento.jaIniciado, isFalse);
  });
}
