import 'package:clubbar_cliente/utils/app_snackbar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSnackBar.mensagemSegura', () {
    test('preserva mensagem clara de regra de negócio', () {
      expect(
        AppSnackBar.mensagemSegura('Seu carrinho está vazio.'),
        'Seu carrinho está vazio.',
      );
    });

    test('oculta detalhe técnico da infraestrutura', () {
      expect(
        AppSnackBar.mensagemSegura('MySQL server has gone away'),
        'Não foi possível concluir a operação agora. Tente novamente em instantes.',
      );
    });

    test('traduz tempo limite de conexão', () {
      expect(
        AppSnackBar.mensagemSegura('TimeoutException: Tempo limite'),
        'O servidor demorou para responder. Tente novamente.',
      );
    });
  });
}
