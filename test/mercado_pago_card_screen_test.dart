import 'dart:convert';

import 'package:clubbar_cliente/screens/pagamento/mercado_pago_card_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  for (final parcelado in [false, true]) {
    testWidgets(
      'devolve token e metadados após limpeza PCI (parcelado: $parcelado)',
      (tester) async {
        const fingerprint = MethodChannel('mercadopago/fingerprint');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          fingerprint,
          (_) async => <String, dynamic>{},
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            fingerprint,
            null,
          ),
        );
        var tokenRequests = 0;
        MercadoPagoCardData? returned;
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/payment_methods')) {
            return http.Response(
              jsonEncode([
                {
                  'id': 'visa',
                  'payment_type_id': 'credit_card',
                  'status': 'active',
                },
              ]),
              200,
            );
          }
          if (request.url.path.endsWith('/installments')) {
            return http.Response(
              jsonEncode([
                {
                  'payment_method_id': 'visa',
                  'payment_type_id': 'credit_card',
                  'issuer': {'id': 'issuer-test'},
                  'payer_costs': [
                    {
                      'installments': 3,
                      'installment_amount': 10,
                      'total_amount': 30,
                    },
                  ],
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/v1/card_tokens') {
            tokenRequests++;
            return http.Response('{"id":"test-token"}', 201);
          }
          if (request.url.path == '/tracks') return http.Response('{}', 200);
          throw StateError('Requisição inesperada no teste');
        });
        await http.runWithClient(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        returned = await Navigator.of(context)
                            .push<MercadoPagoCardData>(
                              MaterialPageRoute(
                                builder: (_) => MercadoPagoCardScreen(
                                  publicKey: 'TEST-tokenization12345',
                                  payerEmail: 'teste@example.com',
                                  payerDocument: '12345678909',
                                  amount: 30,
                                  permiteParcelamento: parcelado,
                                ),
                              ),
                            );
                      },
                      child: const Text('Abrir cartão'),
                    ),
                  );
                },
              ),
            ),
          );
          await tester.tap(find.text('Abrir cartão'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.descendant(
              of: find.byType(CardNumberField),
              matching: find.byType(TextField),
            ),
            '4111111111111111',
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.descendant(
              of: find.byType(ExpirationDateField),
              matching: find.byType(TextField),
            ),
            '1235',
          );
          await tester.enterText(
            find.descendant(
              of: find.byType(SecurityCodeField),
              matching: find.byType(TextField),
            ),
            '123',
          );
          await tester.enterText(
            find.widgetWithText(TextField, 'Nome no cartão'),
            'TEST USER',
          );
          await tester.ensureVisible(find.byType(FilledButton));
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(
            tokenRequests,
            1,
            reason: tester
                .widgetList<Text>(find.byType(Text))
                .map((t) => t.data)
                .join(' | '),
          );
          expect(returned, isNotNull);
          expect(returned!.token, 'test-token');
          expect(returned!.paymentMethodId, 'visa');
          expect(returned!.installments, parcelado ? 3 : 1);
          expect(returned!.issuerId, parcelado ? 'issuer-test' : null);
          expect(returned!.payerDocument, '12345678909');
          expect(find.byType(MercadoPagoCardScreen), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
          MercadoPagoSDK.shared.dispose();
        }, () => client);
      },
    );
  }

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
