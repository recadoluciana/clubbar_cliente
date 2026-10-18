/// Datas e horas de referência do Clubbar no fuso de São Paulo (UTC-03:00).
///
/// Na web, `DateTime.toLocal()` depende do fuso do navegador. Este utilitário
/// mantém a apresentação consistente para clientes no Brasil e no exterior.
class HorarioBrasil {
  static const _deslocamentoUtc = Duration(hours: -3);

  /// Retorna o horário atual de Brasília, independentemente do aparelho.
  static DateTime agora() => _comoDataCivil(DateTime.now().toUtc());

  /// Converte um timestamp UTC para a data civil de Brasília.
  static DateTime deUtc(DateTime valor) => _comoDataCivil(valor.toUtc());

  /// Lê datas devolvidas pela API. Valores sem fuso já representam o horário
  /// civil brasileiro; valores com `Z` ou offset são normalizados para Brasília.
  static DateTime? deTextoBrasil(Object? valor) {
    final texto = valor?.toString().trim() ?? '';
    if (texto.isEmpty) return null;
    final possuiFuso = RegExp(
      r'(Z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(texto);
    final data = DateTime.tryParse(texto);
    if (data == null) return null;
    return possuiFuso ? deUtc(data) : data;
  }

  /// Lê valores UTC legados que não vieram com o sufixo de fuso.
  static DateTime? deTextoUtc(Object? valor) {
    final texto = valor?.toString().trim() ?? '';
    if (texto.isEmpty) return null;
    final possuiFuso = RegExp(
      r'(Z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(texto);
    final data = DateTime.tryParse(possuiFuso ? texto : '${texto}Z');
    return data == null ? null : deUtc(data);
  }

  static DateTime _comoDataCivil(DateTime utc) {
    final brasil = utc.add(_deslocamentoUtc);
    return DateTime(
      brasil.year,
      brasil.month,
      brasil.day,
      brasil.hour,
      brasil.minute,
      brasil.second,
      brasil.millisecond,
      brasil.microsecond,
    );
  }
}
