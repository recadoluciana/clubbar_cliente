import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:clubbar_cliente/utils/date_formatters.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  test('mostra apenas a hora quando início e término são no mesmo dia', () {
    expect(
      DateFormatters.terminoEvento(
        '2026-11-20T20:00:00',
        '2026-11-20T23:30:00',
      ),
      'até 23h30',
    );
  });

  test('mostra a data quando o evento termina no dia seguinte', () {
    expect(
      DateFormatters.terminoEvento(
        '2026-11-20T20:00:00',
        '2026-11-21T02:00:00',
      ),
      contains('21/11/2026'),
    );
  });

  test('compara os dias no horário de Brasília', () {
    expect(
      DateFormatters.terminoEvento(
        '2026-11-20T23:00:00Z',
        '2026-11-21T02:00:00Z',
      ),
      'até 23h00',
    );
  });
}
