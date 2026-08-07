import 'package:clubbar_cliente/models/evento_lote.dart';
import 'package:flutter_test/flutter_test.dart';

EventoLote lote({
  String status = 'ATIVO',
  int total = 100,
  int vendida = 0,
  bool semLimite = false,
  String inicio = '',
  String fim = '',
}) {
  return EventoLote(
    loteId: 1,
    eventoId: 1,
    nome: 'Lote único',
    preco: 20,
    qtTotal: total,
    qtVendida: vendida,
    semLimite: semLimite,
    status: status,
    dataInicioVenda: inicio,
    dataFimVenda: fim,
  );
}

void main() {
  final agora = DateTime(2026, 8, 7, 20);

  test('permite lote ativo dentro do período com disponibilidade', () {
    final item = lote(
      inicio: '2026-08-01T00:00:00',
      fim: '2026-08-10T23:59:59',
    );
    expect(item.podeComprarEm(agora), isTrue);
    expect(item.situacaoVendaEm(agora), 'Disponível');
  });

  test('bloqueia lote esgotado', () {
    final item = lote(total: 10, vendida: 10);
    expect(item.podeComprarEm(agora), isFalse);
    expect(item.situacaoVendaEm(agora), 'Esgotado');
  });

  test('bloqueia lote antes e depois do período de venda', () {
    final futuro = lote(inicio: '2026-08-08T20:00:00');
    final encerrado = lote(fim: '2026-08-06T20:00:00');
    expect(futuro.situacaoVendaEm(agora), 'Em breve');
    expect(encerrado.situacaoVendaEm(agora), 'Vendas encerradas');
  });

  test('lote ilimitado não esgota por quantidade', () {
    final item = lote(total: 0, vendida: 500, semLimite: true);
    expect(item.podeComprarEm(agora), isTrue);
  });
}
