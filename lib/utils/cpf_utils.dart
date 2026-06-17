class CpfUtils {
  static String somenteNumeros(String? valor) {
    if (valor == null) return '';
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static bool validar(String? cpf) {
    final numeros = somenteNumeros(cpf);

    if (numeros.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(numeros)) return false;

    int soma = 0;

    for (int i = 0; i < 9; i++) {
      soma += int.parse(numeros[i]) * (10 - i);
    }

    int resto = soma % 11;
    int digito1 = resto < 2 ? 0 : 11 - resto;

    if (digito1 != int.parse(numeros[9])) return false;

    soma = 0;

    for (int i = 0; i < 10; i++) {
      soma += int.parse(numeros[i]) * (11 - i);
    }

    resto = soma % 11;
    int digito2 = resto < 2 ? 0 : 11 - resto;

    return digito2 == int.parse(numeros[10]);
  }

  static String formatar(String? cpf) {
    final numeros = somenteNumeros(cpf);

    if (numeros.length != 11) return numeros;

    return '${numeros.substring(0, 3)}.'
        '${numeros.substring(3, 6)}.'
        '${numeros.substring(6, 9)}-'
        '${numeros.substring(9, 11)}';
  }
}
