// lib/utils/date_formatters.dart
import 'package:intl/intl.dart';

class DateFormatters {
  static String dataCompleta(String valor) {
    if (valor.trim().isEmpty) return 'Data não informada';

    try {
      final data = DateTime.parse(valor).toLocal();

      final diaSemana = DateFormat('EEEE', 'pt_BR').format(data);
      final dataFormatada = DateFormat('dd/MM/yyyy').format(data);
      final hora = DateFormat('HH:mm').format(data);

      final diaSemanaCapitalizado =
          diaSemana[0].toUpperCase() + diaSemana.substring(1);

      return '$diaSemanaCapitalizado, $dataFormatada, $hora';
    } catch (_) {
      return valor;
    }
  }

  static String dataHoraSimples(String valor) {
    if (valor.trim().isEmpty) return 'Não informado';

    try {
      final data = DateTime.parse(valor).toLocal();
      return DateFormat('dd/MM/yyyy, HH:mm', 'pt_BR').format(data);
    } catch (_) {
      return valor;
    }
  }

  static String periodo(String inicio, String fim) {
    final ini = dataCompleta(inicio);
    final fimFmt = dataCompleta(fim);

    if (inicio.trim().isEmpty && fim.trim().isEmpty) {
      return 'Período não informado';
    }

    if (inicio.trim().isEmpty) {
      return 'Até $fimFmt';
    }

    if (fim.trim().isEmpty) {
      return 'A partir de $ini';
    }

    return '$ini até $fimFmt';
  }
}