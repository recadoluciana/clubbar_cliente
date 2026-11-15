import 'package:clubbar_cliente/screens/pagamento/mercado_pago_card_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mercadopago_sdk_flutter/mercadopago_sdk_flutter.dart';

const _initializationError =
    'Não foi possível iniciar o pagamento com cartão. Tente novamente.';

Widget _screen(String publicKey) => MaterialApp(
  home: MercadoPagoCardScreen(
    publicKey: publicKey,
    payerEmail: 'teste@example.com',
    payerDocument: '',
    amount: 10,
  ),
);

void main() {
  setUp(() => MercadoPagoSDK.shared.dispose());
  tearDown(() => MercadoPagoSDK.shared.dispose());

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('inicializa formulário brasileiro em $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(_screen('TEST-initialization12345'));

      expect(find.text(_initializationError), findsNothing);
      expect(MercadoPagoSDK.shared.isInitialized, isTrue);
      expect(MercadoPagoSDK.shared.configuration.country, Country.brazil);
      expect(MercadoPagoSDK.shared.configuration.locale, 'pt-BR');
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(find.text('Número do cartão'), findsOneWidget);
      expect(find.text('Validade'), findsOneWidget);
      expect(find.text('Código de segurança'), findsOneWidget);
      expect(find.text('Card number'), findsNothing);
      expect(find.text('Expiration'), findsNothing);
      expect(find.text('Security code'), findsNothing);
      expect(
        tester
            .widget<ExpirationDateField>(find.byType(ExpirationDateField))
            .hintText,
        'MM/AA',
      );

      // Voltar ao checkout de outra loja deve substituir a configuração.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_screen('TEST-anotherstore12345'));
      expect(find.text(_initializationError), findsNothing);
      expect(
        MercadoPagoSDK.shared.configuration.publicKey,
        'TEST-anotherstore12345',
      );
      expect(MercadoPagoSDK.shared.configuration.country, Country.brazil);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      MercadoPagoSDK.shared.dispose();
    });
  }

  testWidgets('chave inválida mantém pagamento bloqueado', (tester) async {
    await tester.pumpWidget(_screen('invalid-key'));
    expect(find.text(_initializationError), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
