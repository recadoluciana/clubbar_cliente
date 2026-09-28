DateTime obterExpiracaoPix(
  Map<String, dynamic> pagamento, {
  DateTime? agora,
  Duration duracaoMaxima = const Duration(minutes: 5),
}) {
  final referencia = agora ?? DateTime.now();
  final valor =
      pagamento['expiration_date'] ?? pagamento['pix_expiration_date'];
  var texto = valor?.toString().trim() ?? '';
  if (texto.isNotEmpty &&
      !RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false).hasMatch(texto)) {
    texto = '${texto}Z';
  }

  final data = DateTime.tryParse(texto)?.toLocal();
  final limite = referencia.add(duracaoMaxima);
  if (data == null || data.isAfter(limite)) return limite;
  return data;
}
