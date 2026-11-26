import 'dart:convert';

import 'package:clubbar_cliente/models/loja.dart';
import 'package:clubbar_cliente/screens/atendimento_cora/atendimento_cora_screen.dart';
import 'package:clubbar_cliente/screens/carrinho/carrinho_screen.dart';
import 'package:clubbar_cliente/screens/carteira/carteira_screen.dart';
import 'package:clubbar_cliente/screens/detalhe_evento/detalhe_evento_screen.dart';
import 'package:clubbar_cliente/screens/detalhe_evento/participantes_reserva_screen.dart';
import 'package:clubbar_cliente/screens/home/home_screen.dart';
import 'package:clubbar_cliente/screens/main/main_navigation_screen.dart';
import 'package:clubbar_cliente/services/main_navigation_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await initializeDateFormatting('pt_BR');
    SharedPreferences.setMockInitialValues({'cliente_id': 1});
    PackageInfo.setMockInitialValues(
      appName: 'Clubbar',
      packageName: 'clubbar',
      version: '1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => 'test-token',
    );
    for (final channel in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    MainNavigationController.irParaHome();
  });

  Future<void> executar(
    WidgetTester tester,
    Future<void> Function(List<http.Request> requests) verificar,
  ) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      final Object resposta;
      if (path == '/eventos/10') {
        resposta = {
          'evento_id': 10,
          'nmtituloevento': 'Festival',
          'nmloja': 'Casa',
          'dtinicioevento': '2099-12-13T13:00:00',
          'statusevento': 'ATIVO',
        };
      } else if (path == '/eventos/10/lotes') {
        resposta = [
          for (var id = 1; id <= 2; id++)
            {
              'lote_id': id,
              'loteglobal_id': 1,
              'evento_id': 10,
              'nmlote': 'Lote 1',
              'nmsetor': id == 1 ? 'Pista' : 'VIP',
              'qttotallote': 50,
              'precos': [
                {'lotepreco_id': id, 'nmpreco': 'Inteira', 'vrpreco': 10},
              ],
            },
        ];
      } else if (path == '/reservas-ingressos/compra-evento') {
        resposta = {
          'compra_evento_id': 20,
          'reserva_ingresso_id': 30,
          'cliente_id': 1,
          'quantidade': 1,
          'segundos_restantes': 900,
          'itens': [
            {
              'reserva_ingresso_id': 30,
              'quantidade': 1,
              'nome_modalidade': 'Inteira',
              'nome_setor': 'Pista',
              'valor_unitario': 10,
              'valor_total': 10,
            },
          ],
        };
      } else if (path.endsWith('/quantidade-vendida')) {
        resposta = {'qtvendidalote': 0, 'qtdisponivel': 50};
      } else if (path.contains('carrinho') ||
          path.contains('get_carteira_qt')) {
        resposta = {'itens': [], 'qt_total': 0};
      } else if (path == '/health') {
        resposta = {'api': 'online', 'database': 'online'};
      } else if (request.method == 'POST') {
        resposta = {};
      } else {
        resposta = [];
      }
      return http.Response(
        jsonEncode(resposta),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await http.runWithClient(() async {
      MainNavigationController.abrirTela(
        DetalheEventoScreen(
          eventoId: 10,
          loja: Loja.fromJson({
            'loja_id': 5,
            'organizacao_id': 1,
            'nmloja': 'Casa',
          }),
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Setor: Pista'));
      await tester.tap(find.text('Setor: Pista'));
      await tester.pumpAndSettle();
      expect(find.text('Inteira'), findsOneWidget);
      for (final item in ['Home', 'Carrinho', 'Carteira', 'Cora responde']) {
        expect(find.text(item), findsOneWidget);
      }
      // O setor permanece dentro do shell; não cobre a navegação com outra rota.
      expect(
        Navigator.of(
          tester.element(find.text('Inteira')),
          rootNavigator: true,
        ).canPop(),
        isFalse,
      );
      await verificar(requests);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }, () => client);
    MainNavigationController.irParaHome();
    expect(tester.takeException(), isNull);
  }

  testWidgets('Voltar do setor mantém o detalhe montado', (tester) async {
    await executar(tester, (requests) async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Comprar ingresso'), findsOneWidget);
      expect(find.text('Setor: VIP'), findsOneWidget);
      expect(requests.where((r) => r.url.path == '/eventos/10'), hasLength(1));
      expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
      expect(
        MainNavigationController.telaInterna.value,
        isA<DetalheEventoScreen>(),
      );
    });
  });

  testWidgets(
    'sacola e participantes preservam a reserva ao voltar ao evento',
    (tester) async {
      await executar(tester, (requests) async {
        // A fonte de teste Ahem é mais larga que a usada pelo aplicativo.
        tester.view.physicalSize = const Size(800, 1000);
        await tester.pump();
        await tester.tap(find.text('Adicionar'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Conferir sacola'));
        await tester.pumpAndSettle();
        expect(find.text('Conferir sacola'), findsOneWidget);
        expect(find.text('1x Inteira'), findsOneWidget);
        for (final item in ['Home', 'Carrinho', 'Carteira', 'Cora responde']) {
          expect(find.text(item), findsOneWidget);
        }
        await tester.tap(find.text('Continuar - Informar participante'));
        await tester.pumpAndSettle();
        expect(find.byType(ParticipantesReservaScreen), findsOneWidget);
        expect(find.text('Participante 1'), findsOneWidget);
        expect(find.text('Home'), findsNothing);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(find.text('Conferir sacola'), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(find.text('Inteira'), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(find.text('Comprar ingresso'), findsOneWidget);
        await tester.tap(find.byTooltip('Continuar para participantes'));
        await tester.pumpAndSettle();
        expect(find.text('1x Inteira'), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Comprar ingresso'), findsOneWidget);
        expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
        expect(
          requests.where(
            (r) => r.url.path == '/reservas-ingressos/compra-evento',
          ),
          hasLength(1),
        );
      });
    },
  );

  for (final origem in ['setor', 'sacola']) {
    for (final destino in ['Home', 'Carrinho', 'Carteira', 'Cora responde']) {
      testWidgets('$origem navega diretamente para $destino', (tester) async {
        await executar(tester, (_) async {
          if (origem == 'sacola') {
            await tester.tap(find.text('Adicionar'));
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Conferir sacola'));
            await tester.pumpAndSettle();
            expect(find.text('Conferir sacola'), findsOneWidget);
            for (final item in [
              'Home',
              'Carrinho',
              'Carteira',
              'Cora responde',
            ]) {
              expect(find.text(item), findsOneWidget);
            }
            expect(
              Navigator.of(
                tester.element(find.text('Conferir sacola')),
                rootNavigator: true,
              ).canPop(),
              isFalse,
            );
          }
          await tester.tap(find.text(destino));
          // Home tem uma animação contínua; não esperamos todas as animações.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump();
          expect(find.text('Setor: Pista'), findsNothing);
          expect(find.text('Conferir sacola'), findsNothing);
          switch (destino) {
            case 'Home':
              expect(find.byType(HomeScreen), findsOneWidget);
            case 'Carrinho':
              expect(find.byType(CarrinhoScreen), findsOneWidget);
              expect(
                tester
                    .widget<CarrinhoScreen>(find.byType(CarrinhoScreen))
                    .loja
                    .id,
                5,
              );
            case 'Carteira':
              expect(find.byType(CarteiraScreen), findsOneWidget);
              expect(
                tester
                    .widget<CarteiraScreen>(find.byType(CarteiraScreen))
                    .lojaSelecionadaId,
                5,
              );
            case 'Cora responde':
              expect(find.byType(AtendimentoCoraScreen), findsOneWidget);
          }
        });
      });
    }
  }
}
