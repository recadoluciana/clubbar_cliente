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
import 'package:clubbar_cliente/screens/pagamento/mercado_pago_card_screen.dart';
import 'package:clubbar_cliente/screens/pagamento/pagamento_sucesso_screen.dart';
import 'package:clubbar_cliente/screens/pagamento/pix_pagamento_screen.dart';
import 'package:clubbar_cliente/services/main_navigation_controller.dart';
import 'package:clubbar_cliente/widgets/clubbar_page_header.dart';
import 'package:clubbar_cliente/widgets/clubbar_app_bar.dart';
import 'package:clubbar_cliente/utils/value_formatters.dart';
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
    int segundosReserva = 900,
    int? segundosStatus,
    bool Function()? statusFalhou,
    bool Function()? reservaExpirada,
    bool respostaExclusaoDesatualizada = false,
    bool cortesiaComPrecoIncorreto = false,
    bool cortesiaApenasPrimeiroSetor = false,
    bool cortesiaEsgotada = false,
    void Function()? verificarSetores,
    double taxaMinima = 0,
    bool setorUnico = false,
    bool variasModalidades = false,
    bool Function()? cotacaoFalhou,
  }) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    final modalidade = cortesia ? 'Cortesia' : 'Inteira';
    final valor = cortesia ? (cortesiaComPrecoIncorreto ? 3 : 0) : 10;
    final reserva = {
      'compra_evento_id': 20,
      'reserva_ingresso_id': 30,
      'cliente_id': 1,
      'quantidade': 1,
      'segundos_restantes': segundosReserva,
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
      if (path == '/reservas-ingressos/30/status' && statusFalhou?.call() == true) {
        return http.Response(jsonEncode({'detail': 'Sem conexão'}), 500);
      }
      if (path == '/reservas-ingressos/30/cotacao-mercado-pago' && cotacaoFalhou?.call() == true) {
        return http.Response(jsonEncode({'detail': 'Erro na cotação'}), 500);
      }
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
          for (var id = 1; id <= (setorUnico ? 1 : 2); id++)
            {
              'lote_id': id,
              'loteglobal_id': 1,
              'evento_id': 10,
              'nmlote': 'Lote 1',
              'nmsetor': id == 1 ? 'Pista' : 'VIP',
              'qttotallote': 50,
              'precos': [
                {'lotepreco_id': id, 'nmpreco': cortesiaApenasPrimeiroSetor && id == 2 ? 'Inteira' : modalidade, 'tipopreco': cortesiaApenasPrimeiroSetor && id == 2 ? 'INTEIRA' : cortesia ? 'CORTESIA' : 'INTEIRA', 'vrpreco': cortesiaApenasPrimeiroSetor && id == 2 ? 10 : valor, if (cortesiaEsgotada) 'qtdisponivelmodalidade': 0},
                if (variasModalidades && id == 1) {'lotepreco_id': 101, 'nmpreco': 'Meia', 'tipopreco': 'MEIA', 'vrpreco': 5},
                if (variasModalidades && id == 1) {'lotepreco_id': 102, 'nmpreco': 'Esgotado', 'tipopreco': 'INTEIRA', 'vrpreco': 99, 'qtdisponivelmodalidade': 0},
              ],
            },
        ];
      } else if (path == '/reservas-ingressos/resgate-cortesia') {
        resposta = {'gratuito': true, 'venda_id': 40};
      } else if (path == '/reservas-ingressos/compra-evento') {
        resposta = reserva;
      } else if (path == '/reservas-ingressos/compra-evento/20/ingressos/30' && request.method == 'DELETE') {
        // Simula também a resposta antiga que incluía o item recém-removido.
        resposta = respostaExclusaoDesatualizada
            ? {...reserva, 'ok': true}
            : {'ok': true, 'quantidade': 0, 'valor_total': 0, 'itens': []};
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
          if (segundosStatus != null) 'segundos_restantes': segundosStatus,
          if (reservaExpirada?.call() == true) ...{
            'status': 'EXPIRADA',
            'segundos_restantes': 0,
          },
          if (statusPagamento != null) 'status_pagamento': statusPagamento(),
        };
      } else if (path == '/clientes/me') {
        resposta = {'nrcpfcliente': '12345678909'};
      } else if (path == '/reservas-ingressos/30/cotacao-mercado-pago') {
        resposta = {
          'ingressos': valor,
          'conveniencia': 0,
          'percentual_conveniencia': 0,
          'processamento': 0.2,
          'total': valor + 0.2,
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
        resposta = {'provedor_pagamento': provedor, 'mercado_pago_public_key': 'TEST-key'};
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
            'vrtaxaminimaingresso': taxaMinima,
          }),
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));
      await tester.pumpAndSettle();
      verificarSetores?.call();
      if (!setorUnico) {
        await tester.ensureVisible(find.text('Setor: Pista'));
        await tester.tap(find.text('Setor: Pista'));
        await tester.pumpAndSettle();
      }
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

  testWidgets('cabeçalho do setor mostra data entre evento e setor', (tester) async {
    await executar(tester, (_) async {
      final nome = find.text('Festival');
      final data = find.text('Data: domingo, 13/12/2099 às 13h00');
      final setor = find.text('Setor: Pista');
      expect(nome, findsOneWidget);
      expect(data, findsOneWidget);
      expect(setor, findsOneWidget);
      expect(tester.getCenter(nome).dy, lessThan(tester.getCenter(data).dy));
      expect(tester.getCenter(data).dy, lessThan(tester.getCenter(setor).dy));
    });
  });

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
      await tester.tap(find.text('Adicionar mais ingressos'));
      await tester.pumpAndSettle();
      expect(find.text('Inteira'), findsOneWidget);
      await tester.tap(find.byTooltip('Conferir sacola'));
      await tester.pumpAndSettle();
      expect(find.text('15:00'), findsNothing);
      expect(find.textContaining(RegExp(r'13:5[0-9]|14:00')), findsWidgets);
    }, segundosReserva: 840);
  });

  testWidgets('excluir último ingresso esvazia a sacola no primeiro clique', (tester) async {
    await executar(tester, (requests) async {
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      final sacola = find.ancestor(of: find.byTooltip('Conferir sacola'), matching: find.byType(Stack)).first;
      expect(find.descendant(of: sacola, matching: find.text('1')), findsOneWidget);
      await tester.tap(find.byTooltip('Conferir sacola'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Excluir ingresso'));
      await tester.pumpAndSettle();
      expect(find.byType(ParticipantesReservaScreen), findsNothing);
      expect(find.descendant(of: sacola, matching: find.text('1')), findsNothing);
      expect(requests.where((r) => r.method == 'DELETE' && r.url.path == '/reservas-ingressos/compra-evento/20/ingressos/30'), hasLength(1));
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.method == 'POST' && r.url.path == '/reservas-ingressos/compra-evento'), hasLength(2));
      expect(requests.where((r) => r.method == 'POST' && r.url.path == '/reservas-ingressos/compra-evento/20/ingressos'), isEmpty);
    }, respostaExclusaoDesatualizada: true);
  });

  testWidgets('idas e voltas preservam o mesmo prazo entre todas as telas', (tester) async {
    await executar(tester, (_) async {
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Conferir sacola'));
      await tester.pumpAndSettle();
      final prazo = tester.widget<ParticipantesReservaScreen>(find.byType(ParticipantesReservaScreen)).prazoReserva;
      expect(prazo, isNotNull);
      await tester.enterText(find.widgetWithText(TextField, 'Nome completo'), 'Pessoa Teste');
      await tester.enterText(find.widgetWithText(TextField, 'CPF'), '12345678909');
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Continuar para pagamento'));
        await tester.pumpAndSettle();
        expect(tester.widget<EscolhaPagamentoScreen>(find.byType(EscolhaPagamentoScreen)).reservaExpiracao, prazo);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Adicionar mais ingressos'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Conferir sacola'));
        await tester.pumpAndSettle();
        expect(tester.widget<ParticipantesReservaScreen>(find.byType(ParticipantesReservaScreen)).prazoReserva, prazo);
        expect(find.text('Pessoa Teste'), findsOneWidget);
      }
    }, segundosReserva: 840, segundosStatus: 900);
  });

  testWidgets('contador continua ao voltar sem resposta do servidor', (tester) async {
    var falhou = false;
    await executar(tester, (_) async {
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Conferir sacola'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nome completo'), 'Pessoa Teste');
      await tester.enterText(find.widgetWithText(TextField, 'CPF'), '12345678909');
      await tester.tap(find.text('Continuar para pagamento'));
      await tester.pumpAndSettle();
      falhou = true;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      int segundosNoTopo() {
        final texto = tester.widget<Text>(find.descendant(
          of: find.byType(ClubbarAppBar),
          matching: find.byWidgetPredicate((widget) => widget is Text && RegExp(r'^\d{2}:\d{2}$').hasMatch(widget.data ?? '')),
        )).data!;
        final partes = texto.split(':').map(int.parse).toList();
        return partes[0] * 60 + partes[1];
      }
      final antes = segundosNoTopo();
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
      await tester.pump(const Duration(seconds: 1));
      expect(segundosNoTopo(), lessThan(antes));
    }, segundosReserva: 840, statusFalhou: () => falhou);
  });

  testWidgets('prazo expirado no pagamento limpa a sacola ao voltar', (tester) async {
    var expirou = false;
    await executar(tester, (requests) async {
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Conferir sacola'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nome completo'), 'Participante Teste');
      await tester.enterText(find.widgetWithText(TextField, 'CPF'), '12345678909');
      await tester.tap(find.text('Continuar para pagamento'));
      await tester.pumpAndSettle();
      expect(find.byType(EscolhaPagamentoScreen), findsOneWidget);
      expirou = true;
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('O tempo para a compra expirou'), findsOneWidget);
      await tester.tap(find.text('VOLTAR'));
      await tester.pumpAndSettle();
      expect(find.byType(ParticipantesReservaScreen), findsNothing);
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.method == 'POST' && r.url.path == '/reservas-ingressos/compra-evento'), hasLength(2));
    }, segundosReserva: 2, reservaExpirada: () => expirou);
  });

  testWidgets('resumo oficial é exibido antes do Pix sem confirmação extra', (tester) async {
    await executar(tester, (requests) async {
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Conferir sacola'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nome completo'), 'Pessoa Teste');
      await tester.enterText(find.widgetWithText(TextField, 'CPF'), '12345678909');
      await tester.tap(find.text('Continuar para pagamento'));
      await tester.pumpAndSettle();
      expect(find.text('Taxa de conveniência (0%)'), findsOneWidget);
      expect(find.text('Taxa de processamento (2%)'), findsOneWidget);
      expect(find.text('R\$ 0,20'), findsOneWidget);
      expect(find.text('Total a pagar'), findsOneWidget);
      expect(find.text('R\$ 10,20'), findsOneWidget);
      expect(find.text('Entenda as taxas'), findsOneWidget);
      await tester.tap(find.text('Pagamento PIX'));
      await tester.pumpAndSettle();
      expect(find.text('Confirme o valor'), findsNothing);
      final envio = requests.where((r) => r.method == 'POST' && r.url.path == '/reservas-ingressos/30/mercado-pago').single;
      expect((jsonDecode(envio.body) as Map)['valor_total_confirmado'], 10.2);
      expect(find.byType(PixPagamentoScreen), findsOneWidget);
    });
  });

  testWidgets('cartão abre diretamente após exibir a cotação', (tester) async {
    await executar(tester, (_) async {
      tester.view.physicalSize = const Size(800, 1200);
      await tester.pump();
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Conferir sacola'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nome completo'), 'Pessoa Teste');
      await tester.enterText(find.widgetWithText(TextField, 'CPF'), '12345678909');
      await tester.tap(find.text('Continuar para pagamento'));
      await tester.pumpAndSettle();
      expect(find.text('R\$ 10,20'), findsOneWidget);
      await tester.tapAt(tester.getTopLeft(find.widgetWithText(ElevatedButton, 'Pagamento com cartão de crédito')) + const Offset(20, 12));
      await tester.pumpAndSettle();
      expect(find.text('Confirme o valor'), findsNothing);
      expect(find.byType(MercadoPagoCardScreen), findsOneWidget);
    });
  });

  testWidgets('erro na cotação bloqueia pagamento e permite nova tentativa', (tester) async {
    var falhou = true;
    await executar(tester, (requests) async {
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Conferir sacola'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nome completo'), 'Pessoa Teste');
      await tester.enterText(find.widgetWithText(TextField, 'CPF'), '12345678909');
      await tester.tap(find.text('Continuar para pagamento'));
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível carregar o resumo da compra.'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Pagamento PIX')).onPressed, isNull);
      expect(requests.where((r) => r.url.path == '/reservas-ingressos/30/mercado-pago'), isEmpty);
      falhou = false;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('R\$ 10,20'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Pagamento PIX')).onPressed, isNotNull);
    }, cotacaoFalhou: () => falhou);
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

  testWidgets('detalhe direto mostra total na linha do preço e quantidade', (tester) async {
    await executar(tester, (_) async {
      tester.view.physicalSize = const Size(800, 1000);
      await tester.pump();
      final unitario = find.byWidgetPredicate((widget) => widget is Text &&
        widget.textSpan?.toPlainText().contains(ValueFormatters.moeda(10) + ' (+' + ValueFormatters.moeda(2.99) + ')') == true);
      final aumentar = find.byTooltip('Aumentar quantidade');
      final total = find.text(ValueFormatters.moeda(12.99));
      await tester.ensureVisible(aumentar);
      await tester.pump();
      expect(unitario, findsOneWidget);
      expect(total, findsOneWidget);
      expect(find.text('Subtotal'), findsNothing);
      expect(tester.getCenter(unitario).dy, closeTo(tester.getCenter(aumentar).dy, 1));
      expect(tester.getCenter(total).dy, closeTo(tester.getCenter(aumentar).dy, 1));
      expect(tester.widget<Text>(total).style?.fontSize, 17);
      final limite = find.text('5 ingressos por compra');
      final disponivel = find.text('Disponível');
      final adicionar = find.widgetWithText(FilledButton, 'Adicionar');
      expect(tester.getCenter(limite).dy, greaterThan(tester.getCenter(unitario).dy));
      expect(tester.getCenter(disponivel).dy, closeTo(tester.getCenter(limite).dy, 1));
      expect(tester.getCenter(adicionar).dy, closeTo(tester.getCenter(limite).dy, 1));
      await tester.tap(aumentar);
      await tester.pump();
      expect(find.text(ValueFormatters.moeda(25.98)), findsOneWidget);
    }, taxaMinima: 2.99, setorUnico: true);
  });

  testWidgets('preço, quantidade e total aparecem na mesma linha', (tester) async {
    await executar(tester, (_) async {
      tester.view.physicalSize = const Size(800, 1000);
      await tester.pump();
      final unitario = find.byWidgetPredicate((widget) => widget is Text &&
        widget.textSpan?.toPlainText().contains(ValueFormatters.moeda(10) + ' (+' + ValueFormatters.moeda(2.99) + ')') == true);
      final aumentar = find.byTooltip('Aumentar quantidade');
      final totalInicial = find.text(ValueFormatters.moeda(12.99));
      expect(unitario, findsOneWidget);
      expect(totalInicial, findsOneWidget);
      expect(find.text('Subtotal'), findsNothing);
      expect(tester.getCenter(unitario).dy, closeTo(tester.getCenter(aumentar).dy, 1));
      expect(tester.getCenter(totalInicial).dy, closeTo(tester.getCenter(aumentar).dy, 1));
      expect(tester.getCenter(unitario).dx, lessThan(tester.getCenter(aumentar).dx));
      expect(tester.getCenter(totalInicial).dx, greaterThan(tester.getCenter(aumentar).dx));
      final limite = find.text('5 ingressos por compra');
      final disponivel = find.text('Disponível');
      final adicionar = find.widgetWithText(FilledButton, 'Adicionar');
      expect(tester.getCenter(limite).dy, greaterThan(tester.getCenter(unitario).dy));
      expect(tester.getCenter(disponivel).dy, closeTo(tester.getCenter(limite).dy, 1));
      expect(tester.getCenter(adicionar).dy, closeTo(tester.getCenter(limite).dy, 1));
      await tester.tap(aumentar);
      await tester.pump();
      expect(find.text(ValueFormatters.moeda(25.98)), findsOneWidget);
    }, taxaMinima: 2.99);
  });

  testWidgets('setores mostram orientação e faixa de preços disponíveis', (tester) async {
    await executar(tester, (_) async {}, variasModalidades: true,
      verificarSetores: () {
        final pista = find.ancestor(of: find.text('Setor: Pista'), matching: find.byType(Card)).first;
        final vip = find.ancestor(of: find.text('Setor: VIP'), matching: find.byType(Card)).first;
        expect(find.text('Selecione um setor'), findsOneWidget);
        expect(find.descendant(of: pista, matching: find.text('Preços entre ' + ValueFormatters.moeda(5) + ' e ' + ValueFormatters.moeda(10))), findsOneWidget);
        expect(find.descendant(of: vip, matching: find.text('Preço: ' + ValueFormatters.moeda(10))), findsOneWidget);
        expect(find.textContaining('99,00'), findsNothing);
      });
  });

  testWidgets('faixa inclui cortesia disponível com valor zero', (tester) async {
    await executar(tester, (_) async {}, cortesia: true, variasModalidades: true,
      verificarSetores: () {
        final pista = find.ancestor(of: find.text('Setor: Pista'), matching: find.byType(Card)).first;
        expect(find.descendant(of: pista, matching: find.text('Preços entre ' + ValueFormatters.moeda(0) + ' e ' + ValueFormatters.moeda(5))), findsOneWidget);
        expect(find.descendant(of: pista, matching: find.text('Cortesia disponível')), findsOneWidget);
      });
  });

  testWidgets('aviso de cortesia aparece apenas no setor disponível', (tester) async {
    await executar(tester, (_) async {}, cortesia: true,
      cortesiaApenasPrimeiroSetor: true,
      verificarSetores: () {
        final setorPista = find.ancestor(of: find.text('Setor: Pista'), matching: find.byType(Card)).first;
        final setorVip = find.ancestor(of: find.text('Setor: VIP'), matching: find.byType(Card)).first;
        expect(find.descendant(of: setorPista, matching: find.text('Cortesia disponível')), findsOneWidget);
        expect(find.descendant(of: setorVip, matching: find.text('Cortesia disponível')), findsNothing);
      });
  });

  testWidgets('não exibe aviso de cortesia esgotada', (tester) async {
    await executar(tester, (_) async {}, cortesia: true,
      cortesiaEsgotada: true,
      verificarSetores: () => expect(find.text('Cortesia disponível'), findsNothing));
  });

  testWidgets('cortesia abre popup e resgata um CPF sem usar sacola', (tester) async {
    await executar(tester, (requests) async {
      expect(find.text('Resgatar'), findsOneWidget);
      await tester.tap(find.text('Resgatar'));
      await tester.pumpAndSettle();
      expect(find.text('Resgatar cortesia'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Resgatar cortesia'));
      await tester.pump();
      expect(find.text('Confira o nome e o CPF do participante.'), findsOneWidget);
      expect(requests.where((r) => r.url.path == '/reservas-ingressos/resgate-cortesia'), isEmpty);
      await tester.enterText(find.widgetWithText(TextField, 'Nome completo'), 'Pessoa Teste');
      await tester.enterText(find.widgetWithText(TextField, 'CPF'), '12345678909');
      await tester.tap(find.widgetWithText(FilledButton, 'Resgatar cortesia'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      final envio = requests.where((r) => r.url.path == '/reservas-ingressos/resgate-cortesia').single;
      final corpo = jsonDecode(envio.body) as Map<String, dynamic>;
      expect(corpo['quantidade'], 1);
      expect(corpo['participante']['cpf'], '12345678909');
      expect(requests.where((r) => r.url.path == '/reservas-ingressos/compra-evento'), isEmpty);
      expect(find.text('Resgate realizado com sucesso'), findsOneWidget);
    }, cortesia: true);
  });

  testWidgets('cortesia com preço incorreto abre resgate sem sacola', (tester) async {
    await executar(tester, (requests) async {
      expect(find.text('Limite de 1 ingresso por CPF'), findsOneWidget);
      expect(find.text('Subtotal'), findsNothing);
      expect(find.text('Resgatar'), findsOneWidget);
      await tester.tap(find.text('Resgatar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nome completo'), 'Pessoa Teste');
      await tester.enterText(find.widgetWithText(TextField, 'CPF'), '12345678909');
      await tester.tap(find.widgetWithText(FilledButton, 'Resgatar cortesia'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(requests.where((r) => r.url.path == '/reservas-ingressos/resgate-cortesia'), hasLength(1));
      expect(requests.where((r) => r.url.path == '/reservas-ingressos/compra-evento'), isEmpty);
      expect(find.text('Resgate realizado com sucesso'), findsOneWidget);
    }, cortesia: true, cortesiaComPrecoIncorreto: true);
  });

  testWidgets('permite resgatar novamente com outro CPF', (tester) async {
    await executar(tester, (requests) async {
      Future<void> resgatar(String nome, String cpf) async {
        await tester.tap(find.text('Resgatar'));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextField, 'Nome completo'), nome);
        await tester.enterText(find.widgetWithText(TextField, 'CPF'), cpf);
        await tester.tap(find.widgetWithText(FilledButton, 'Resgatar cortesia'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(find.text('Resgate realizado com sucesso'), findsOneWidget);
      }
      await resgatar('Pessoa Um', '12345678909');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await resgatar('Pessoa Dois', '52998224725');
      final envios = requests.where((r) => r.url.path == '/reservas-ingressos/resgate-cortesia').toList();
      expect(envios, hasLength(2));
      expect(jsonDecode(envios[0].body)['participante']['cpf'], '12345678909');
      expect(jsonDecode(envios[1].body)['participante']['cpf'], '52998224725');
      expect(requests.where((r) => r.url.path == '/reservas-ingressos/compra-evento'), isEmpty);
    }, cortesia: true);
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
            expect(find.text('Confirme o valor'), findsNothing);
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
