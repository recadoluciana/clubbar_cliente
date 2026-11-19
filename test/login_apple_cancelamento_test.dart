import 'package:clubbar_cliente/screens/login/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  test('identifica apenas o fechamento da janela Apple como cancelamento', () {
    expect(
      loginAppleCanceladoNoNavegador(
        const SignInWithAppleCredentialsException(
          message: 'Authentication failed with popup_closed_by_user',
        ),
      ),
      isTrue,
    );
    expect(
      loginAppleCanceladoNoNavegador(
        const SignInWithAppleCredentialsException(
          message: 'Authentication failed with network_error',
        ),
      ),
      isFalse,
    );
  });
}
