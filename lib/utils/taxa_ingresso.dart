/// Calcula em centavos a taxa unitária de ingresso, como na reserva da API.
double calcularTaxaIngresso(double preco, double percentual, double minimo) {
  final precoCentavos = (preco * 100).round();
  if (precoCentavos <= 0) return 0;
  final percentualCent = (percentual * 100).round();
  final taxaCalculada = (precoCentavos * percentualCent / 10000).round();
  final minimoCentavos = (minimo * 100).round();
  return (taxaCalculada > minimoCentavos ? taxaCalculada : minimoCentavos) /
      100;
}
