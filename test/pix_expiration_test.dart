import 'package:clubbar_cliente/utils/pix_expiration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final agora = DateTime.utc(2026, 9, 23, 12);

  test(
    'mantém validade informada pelo servidor quando é menor que 5 minutos',
    () {
      final expiracao = obterExpiracaoPix({
        'expiration_date': '2026-09-23T12:03:00Z',
      }, agora: agora);
      expect(expiracao.toUtc(), DateTime.utc(2026, 9, 23, 12, 3));
    },
  );

  test('limita timestamp incorreto que mostraria horas no contador', () {
    final expiracao = obterExpiracaoPix({
      'expiration_date': '2026-09-23T15:04:00Z',
    }, agora: agora);
    expect(expiracao.toUtc(), DateTime.utc(2026, 9, 23, 12, 5));
  });

  test('usa cinco minutos quando a API não informa validade', () {
    final expiracao = obterExpiracaoPix({}, agora: agora);
    expect(expiracao.toUtc(), DateTime.utc(2026, 9, 23, 12, 5));
  });
}
