import 'dart:convert';

import 'package:clubbar_cliente/models/loja.dart';
import 'package:clubbar_cliente/screens/atendimento_cora/atendimento_cora_screen.dart';
import 'package:clubbar_cliente/screens/carrinho/carrinho_lojas_screen.dart';
import 'package:clubbar_cliente/screens/carrinho/carrinho_screen.dart';
import 'package:clubbar_cliente/screens/carteira/carteira_screen.dart';
import 'package:clubbar_cliente/screens/detalhe_evento/detalhe_evento_screen.dart';
import 'package:clubbar_cliente/screens/detalhe_evento/participantes_reserva_screen.dart';
import 'package:clubbar_cliente/screens/detalhe_loja/detalhe_loja_screen.dart';
import 'package:clubbar_cliente/screens/home/home_screen.dart';
import 'package:clubbar_cliente/screens/main/main_navigation_screen.dart';
import 'package:clubbar_cliente/screens/pagamento/escolha_pagamento_screen.dart';
import 'package:clubbar_cliente/screens/pagamento/pagamento_sucesso_screen.dart';
import 'package:clubbar_cliente/screens/pagamento/pix_pagamento_screen.dart';
import 'package:clubbar_cliente/services/main_navigation_controller.dart';
import 'package:clubbar_cliente/widgets/clubbar_page_header.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
    Future<void> Function(List<http.Request> requests) verificar, {
    bool cortesia = false,
    String provedor = 'MERCADO_PAGO',
    String Function()? statusPagamento,
  }) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    final modalidade = cortesia ? 'Cortesia' : 'Inteira';
    final valor = cortesia ? 0 : 10;
    final reserva = {
      'compra_evento_id': 20,
      'reserva_ingresso_id': 30,
      'cliente_id': 1,
      'quantidade': 1,
      'segundos_restantes': 900,
      'valor_total': valor,
      'status': 'PREENCHENDO',
      'itens': [
        {
          'reserva_ingresso_id': 30,
          'quantidade': 1,
          'nome_modalidade': modalidade,
          'nome_setor': 'Pista',
          'valor_unitario': valor,
          'valor_total': valor,
        },
      ],
    };
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
                {'lotepreco_id': id, 'nmpreco': modalidade, 'vrpreco': valor},
              ],
            },
        ];
      } else if (path == '/reservas-ingressos/compra-evento') {
        resposta = reserva;
      } else if (path == '/reservas-ingressos/30/participante') {
        resposta = {'ok': true};
      } else if (path == '/reservas-ingressos/30/participantes') {
        resposta = {
          ...reserva,
          'gratuito': cortesia,
          if (cortesia) 'venda_id': 40,
        };
      } else if (path == '/reservas-ingressos/30' ||
          path == '/reservas-ingressos/30/status') {
        resposta = {
          ...reserva,
          if (statusPagamento != null) 'status_pagamento': statusPagamento(),
        };
      } else if (path == '/clientes/me') {
        resposta = {'nrcpfcliente': '12345678909'};
      } else if (path == '/reservas-ingressos/30/cotacao-mercado-pago') {
        resposta = {
          'ingressos': valor,
          'conveniencia': 0,
          'percentual_conveniencia': 0,
          'processamento': 0,
          'total': valor,
        };
      } else if (path == '/reservas-ingressos/30/mercado-pago' ||
          path == '/reservas-ingressos/30/pix') {
        resposta = {
          'pagamento_id': 'pix-teste',
          'pix_copia_cola': 'codigo-teste',
          'valor_total': valor,
          'expiration_date': '2099-12-13T13:00:00-03:00',
        };
      } else if (path == '/pagamentos/lojas/5/provedor') {
        resposta = {'provedor_pagamento': provedor};
      } else if (path == '/campanhas-doacao/vigente') {
        resposta = {'campanha': null};
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
      expect(find.text(modalidade), findsOneWidget);
      for (final item in ['Home', 'Carrinho', 'Carteira', 'Cora responde']) {
        expect(find.text(item), findsOneWidget);
      }
      // O setor permanece dentro do shell; não cobre a navegação com outra rota.
      expect(
        Navigator.of(
          tester.element(find.text(modalidade)),
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

  testWidgets('tela única mantém o prazo ao voltar e reabrir', (tester) async {
    await executar(tester, (_) async {
      tester.view.physicalSize = const Size(800, 1000);
      await tester.pump();
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 60));
      await tester.tap(find.byTooltip('Conferir sacola'));
      await tester.pumpAndSettle();
      expect(find.byType(ParticipantesReservaScreen), findsOneWidget);
      expect(find.text('Participante 1'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(find.textContaining(RegExp(r'13:5[5-9]|14:00')), findsWidgets);
      await tester.tap(find.text('Adicionar ingresso'));
      await tester.pumpAndSettle();
      expect(find.text('Inteira'), findsOneWidget);
      await tester.tap(find.byTooltip('Conferir sacola'));
      await tester.pumpAndSettle();
      expect(find.text('15:00'), findsNothing);
      expect(find.textContaining(RegExp(r'13:5[0-9]|14:00')), findsWidgets);
    });
  });

  testWidgets('salva participante na tela de conferência sem finalizar compra', (tester) async {
    await executar(tester, (requests) async {
      tester.view.physicalSize = const Size(800, 1000);
      await tester.pump();
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Conferir sacola'));
      await tester.pumpAndSettle();
      expect(find.text('Conferir sacola'), findsOneWidget);
      expect(find.text('Participante 1'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, 'Nome completo'), 'Participante Teste');
      await tester.enterText(find.widgetWithText(TextField, 'CPF'), '12345678909');
      expect(find.text('Participante não salvo'), findsOneWidget);
      await tester.tap(find.text('Salvar participante'));
      await tester.pumpAndSettle();
      expect(find.byType(ParticipantesReservaScreen), findsOneWidget);
      expect(find.text('Participante salvo'), findsOneWidget);
      expect(find.byType(EscolhaPagamentoScreen), findsNothing);
      expect(requests.where((r) => r.method == 'PUT' && r.url.path == '/reservas-ingressos/30/participante'), hasLength(1));
      expect(requests.where((r) => r.url.path == '/reservas-ingressos/30/participantes'), isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Conferir sacola'));
      await tester.pumpAndSettle();
      expect(find.text('Participante Teste'), findsOneWidget);
      expect(find.text('Participante salvo'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Nome completo'), 'Participante Alterado');
      await tester.pump();
      expect(find.text('Alterações não salvas'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Nome completo'), 'Participante Teste');
      await tester.pump();
      expect(find.text('Participante salvo'), findsOneWidget);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'CPF')).controller!.text.replaceAll(RegExp(r'\D'), ''), '12345678909');
      await tester.tap(find.text('Continuar para pagamento'));
      await tester.pumpAndSettle();
      expect(find.byType(EscolhaPagamentoScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Participante Teste'), findsOneWidget);
    });
  });

  for (final origem in [
    'setor',
    'pagamento',
    'pix Mercado Pago',
    'pix Asaas',
  ]) {
    final pix = origem.startsWith('pix');
    final provedor = origem == 'pix Asaas' ? 'ASAAS' : 'MERCADO_PAGO';
    for (final destino in ['Home', 'Carrinho', 'Carteira', 'Cora responde']) {
      testWidgets('$origem navega diretamente para $destino', (tester) async {
        await executar(tester, (_) async {
          if (origem != 'setor') {
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
              expect(find.text(item), findsNothing);
            }
            expect(
              Navigator.of(
                tester.element(find.text('Conferir sacola')),
                rootNavigator: true,
              ).canPop(),
              isFalse,
            );
          }
          if (origem == 'participantes' || origem == 'pagamento' || pix) {
            tester.view.physicalSize = const Size(800, 1000);
            await tester.pump();
            expect(find.byType(ParticipantesReservaScreen), findsOneWidget);
            for (final item in [
              'Home',
              'Carrinho',
              'Carteira',
              'Cora responde',
            ]) {
              expect(find.text(item), findsNothing);
            }
            expect(
              Navigator.of(
                tester.element(find.byType(ParticipantesReservaScreen)),
                rootNavigator: true,
              ).canPop(),
              isFalse,
            );
          }
          if (origem == 'pagamento' || pix) {
            await tester.enterText(
              find.widgetWithText(TextField, 'Nome completo'),
              'Participante Teste',
            );
            await tester.enterText(
              find.widgetWithText(TextField, 'CPF'),
              '12345678909',
            );
            await tester.tap(find.text('Continuar para pagamento'));
            await tester.pumpAndSettle();
            expect(find.byType(EscolhaPagamentoScreen), findsOneWidget);
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
                tester.element(find.byType(EscolhaPagamentoScreen)),
                rootNavigator: true,
              ).canPop(),
              isFalse,
            );
          }
          if (pix) {
            await tester.tap(find.text('Pagamento PIX'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pump();
            if (provedor == 'MERCADO_PAGO') {
              await tester.tap(find.text('Continuar'));
            }
            await tester.pumpAndSettle();
            expect(find.byType(PixPagamentoScreen), findsOneWidget);
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
                tester.element(find.byType(PixPagamentoScreen)),
                rootNavigator: true,
              ).canPop(),
              isFalse,
            );
            tester.view.physicalSize = switch (destino) {
              'Home' => const Size(320, 568),
              'Carteira' => const Size(844, 390),
              _ => const Size(500, 900),
            };
            await tester.pump();
            final resumo = find.byType(ClubbarPageHeader);
            final qrCode = find.byType(QrImageView);
            final copiar = find.widgetWithText(
              ElevatedButton,
              'Copiar código PIX',
            );
            final posicaoResumo = tester.getRect(resumo);
            final posicaoQr = tester.getRect(qrCode);
            final posicaoCopiar = tester.getRect(copiar);
            expect(posicaoResumo.left, 0);
            expect(posicaoResumo.width, tester.view.physicalSize.width);
            expect(posicaoQr.top, greaterThanOrEqualTo(posicaoResumo.bottom));
            expect(
              posicaoCopiar.bottom,
              lessThan(tester.getRect(find.text('Home')).top),
            );
            await tester.drag(find.byType(ListView), const Offset(0, -200));
            await tester.pump();
            expect(tester.getRect(resumo), posicaoResumo);
            expect(tester.getRect(qrCode), posicaoQr);
            expect(tester.getRect(copiar), posicaoCopiar);
            expect(tester.takeException(), isNull);
            // Os tamanhos reduzidos acima verificam o Pix; os destinos usam
            // o tamanho padrão deste teste de navegação.
            tester.view.physicalSize = const Size(500, 1000);
            await tester.pump();
          }
          await tester.tap(find.text(destino));
          // Home tem uma animação contínua; não esperamos todas as animações.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump();
          expect(find.text('Setor: Pista'), findsNothing);
          expect(find.text('Conferir sacola'), findsNothing);
          expect(find.byType(ParticipantesReservaScreen), findsNothing);
          expect(find.byType(EscolhaPagamentoScreen), findsNothing);
          expect(find.byType(PixPagamentoScreen), findsNothing);
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
        }, provedor: provedor);
      });
    }
  }

  for (final fluxo in [
    'retorno',
    'cortesia',
    'cortesia Home',
    'cortesia Carrinho',
    'cortesia Carteira',
    'cortesia Cora responde',
    'cortesia Voltar para Casa',
    'pix pago',
  ]) {
    final cortesia = fluxo.startsWith('cortesia');
    testWidgets('participantes continuam para $fluxo', (tester) async {
      var statusPagamento = 'PENDENTE';
      await executar(
        tester,
        (requests) async {
          tester.view.physicalSize = const Size(800, 1000);
          await tester.pump();
          await tester.tap(find.text('Adicionar'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Conferir sacola'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextField, 'Nome completo'),
            'Participante Teste',
          );
          await tester.enterText(
            find.widgetWithText(TextField, 'CPF'),
            '12345678909',
          );
          await tester.tap(
            find.text(
              cortesia ? 'Resgatar cortesia' : 'Continuar para pagamento',
            ),
          );
          await tester.pumpAndSettle();
          final envio = requests.singleWhere(
            (r) => r.method == 'PUT' && r.url.path.endsWith('/participantes'),
          );
          expect(jsonDecode(envio.body)['participantes'], [
            {'nome': 'Participante Teste', 'cpf': '12345678909'},
          ]);
          if (cortesia) {
            for (final item in [
              'Home',
              'Carrinho',
              'Carteira',
              'Cora responde',
            ]) {
              expect(find.text(item), findsOneWidget);
            }
            expect(find.byType(PagamentoSucessoScreen), findsOneWidget);
            expect(find.text('Resgate realizado com sucesso'), findsOneWidget);
            expect(find.text('Festival'), findsOneWidget);
            expect(find.text('🎉'), findsOneWidget);
            expect(
              find.byType(ParticipantesReservaScreen, skipOffstage: false),
              findsNothing,
            );
            expect(
              find.byType(MainNavigationScreen, skipOffstage: false),
              findsOneWidget,
            );
            final destino = fluxo == 'cortesia'
                ? 'Voltar do sistema'
                : fluxo.substring('cortesia '.length);
            if (destino == 'Voltar do sistema') {
              await tester.binding.handlePopRoute();
            } else {
              await tester.tap(find.text(destino));
            }
            // Home tem animação contínua e Cora pode retornar à confirmação.
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pump();
            expect(find.byType(PagamentoSucessoScreen), findsNothing);
            expect(
              find.byType(ParticipantesReservaScreen, skipOffstage: false),
              findsNothing,
            );
            expect(
              find.byType(MainNavigationScreen, skipOffstage: false),
              findsOneWidget,
            );
            switch (destino) {
              case 'Home':
              case 'Voltar do sistema':
                expect(find.byType(HomeScreen), findsOneWidget);
              case 'Carrinho':
                expect(find.byType(CarrinhoLojasScreen), findsOneWidget);
              case 'Carteira':
                expect(find.byType(CarteiraScreen), findsOneWidget);
              case 'Cora responde':
                expect(find.byType(AtendimentoCoraScreen), findsOneWidget);
              case 'Voltar para Casa':
                expect(find.byType(DetalheLojaScreen), findsOneWidget);
                expect(
                  tester
                      .widget<DetalheLojaScreen>(find.byType(DetalheLojaScreen))
                      .loja
                      .id,
                  5,
                );
            }
          } else {
            for (final item in [
              'Home',
              'Carrinho',
              'Carteira',
              'Cora responde',
            ]) {
              expect(find.text(item), findsOneWidget);
            }
            expect(find.byType(EscolhaPagamentoScreen), findsOneWidget);
            expect(
              tester
                  .widget<EscolhaPagamentoScreen>(
                    find.byType(EscolhaPagamentoScreen),
                  )
                  .totalPagar,
              10,
            );
            await tester.tap(find.text('Pagamento PIX'));
            // O botão mantém o indicador animado enquanto aguarda a confirmação.
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pump();
            expect(find.text('Confirme o valor'), findsOneWidget);
            await tester.tap(find.text('Continuar'));
            await tester.pumpAndSettle();
            expect(find.byType(PixPagamentoScreen), findsOneWidget);
            for (final item in [
              'Home',
              'Carrinho',
              'Carteira',
              'Cora responde',
            ]) {
              expect(find.text(item), findsOneWidget);
            }
            expect(
              requests.where(
                (r) =>
                    r.method == 'POST' &&
                    r.url.path == '/reservas-ingressos/30/mercado-pago',
              ),
              hasLength(1),
            );
            if (fluxo == 'pix pago') {
              statusPagamento = 'PAGO';
              await tester.pump(const Duration(seconds: 3));
              await tester.pumpAndSettle();
              expect(find.byType(PagamentoSucessoScreen), findsOneWidget);
              expect(
                find.text('Pagamento realizado com sucesso'),
                findsOneWidget,
              );
              expect(
                find.byType(PixPagamentoScreen, skipOffstage: false),
                findsNothing,
              );
              expect(
                find.byType(MainNavigationScreen, skipOffstage: false),
                findsOneWidget,
              );
              expect(find.text('Home'), findsNothing);
              return;
            }
            await tester.tap(find.byIcon(Icons.arrow_back));
            await tester.pumpAndSettle();
            expect(find.byType(EscolhaPagamentoScreen), findsOneWidget);
            expect(find.text('Home'), findsOneWidget);
            await tester.tap(find.byIcon(Icons.arrow_back));
            await tester.pumpAndSettle();
            expect(find.byType(ParticipantesReservaScreen), findsOneWidget);
            expect(find.text('Home'), findsNothing);
            expect(find.text('Participante Teste'), findsOneWidget);
            expect(find.text('12345678909'), findsOneWidget);
            await tester.tap(find.byIcon(Icons.arrow_back));
            await tester.pumpAndSettle();
            expect(find.text('Conferir sacola'), findsNothing);
          }
          expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
        },
        cortesia: cortesia,
        statusPagamento: () => statusPagamento,
      );
    });
  }
}
