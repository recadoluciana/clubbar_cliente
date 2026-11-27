import 'horario_brasil.dart';

DateTime obterExpiracaoPix(
  Map<String, dynamic> pagamento, {
  DateTime? agora,
  Duration duracaoMaxima = const Duration(minutes: 5),
  bool respeitarPrazoInformado = false,
}) {
  final referencia = agora ?? HorarioBrasil.agora();
  final valor = respeitarPrazoInformado
      ? pagamento['pix_expiration_date'] ?? pagamento['expiration_date']
      : pagamento['expiration_date'] ?? pagamento['pix_expiration_date'];
  final data = HorarioBrasil.deTextoUtc(valor);
  final limite = referencia.add(duracaoMaxima);
  if (data == null) return limite;
  if (!respeitarPrazoInformado && data.isAfter(limite)) return limite;
  return data;
}
