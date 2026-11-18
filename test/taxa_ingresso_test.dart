import 'package:flutter_test/flutter_test.dart';
import 'package:clubbar_cliente/utils/taxa_ingresso.dart';

void main() {
  test('arredonda a taxa por ingresso antes de multiplicar', () {
    expect(calcularTaxaIngresso(2.50, 1, 0), 0.03);
    expect(calcularTaxaIngresso(2.50, 10, 0), 0.25);
    expect(calcularTaxaIngresso(2.50, 10, 2.99), 2.99);
    expect(calcularTaxaIngresso(0, 10, 2.99), 0);
  });
}
