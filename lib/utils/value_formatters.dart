import 'package:intl/intl.dart';

class ValueFormatters {
  static final NumberFormat _moedaBR = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static final NumberFormat _numeroBR = NumberFormat('#,##0.00', 'pt_BR');

  static String moeda(double valor) {
    return _moedaBR.format(valor);
  }

  static String numero(double valor) {
    return _numeroBR.format(valor);
  }
}
