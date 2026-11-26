import 'dart:async';

import 'package:clubbar_cliente/models/loja.dart';
import 'package:clubbar_cliente/screens/pagamento/escolha_pagamento_screen.dart';
import 'package:clubbar_cliente/services/api_service.dart';
import 'package:clubbar_cliente/services/auth_storage.dart';
import 'package:clubbar_cliente/utils/horario_brasil.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends AuthStorage {
  @override
  Future<int?> obterClienteId() async => 3;
}

class _Api extends ApiService {
  int consultas = 0;
  bool expirada = false;
  Completer<Map<String, dynamic>>? respostaPendente;

  @override
  Future<Map<String, dynamic>> consultarReserva({
    required int reservaId,
    required int clienteId,
  }) async {
    consultas++;
    if (respostaPendente != null) return respostaPendente!.future;
    return expirada
        ? {
            'status': 'EXPIRADA',
            'status_pagamento': 'PENDENTE',
            'segundos_restantes': 0,
          }
        : {
            'status': 'AGUARDANDO_PAGAMENTO',
            'status_pagamento': 'PENDENTE',
            'segundos_restantes': 1800,
          };
  }

  @override
  Future<Map<String, dynamic>?> campanhaDoacaoVigente({
    required int lojaId,
    int? reservaIngressoId,
  }) async => null;

  @override
  Future<Map<String, dynamic>> consultarProvedorPagamentoLoja({
    required int lojaId,
  }) async => {'provedor_pagamento': 'MERCADO_PAGO'};
}

void main() {
  testWidgets('expiração fecha checkout sobre o pagamento no fluxo interno', (
    tester,
  ) async {
    final resposta = Completer<Map<String, dynamic>>();
    final api = _Api()..respostaPendente = resposta;
    final principal = GlobalKey<NavigatorState>();
    final interno = GlobalKey<NavigatorState>();
    bool? resultado;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: principal,
        home: const Scaffold(body: Text('Home')),
      ),
    );
    unawaited(
      principal.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => Navigator(
            key: interno,
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('Participantes')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      interno.currentState!
          .push<bool>(
            MaterialPageRoute(
              builder: (_) => EscolhaPagamentoScreen(
                loja: Loja.fromJson({
                  'loja_id': 1,
                  'organizacao_id': 1,
                  'nmloja': 'Loja',
                }),
                totalProdutos: 0,
                totalIngressos: 5,
                reservaIngressoId: 2,
                reservaExpiracao: HorarioBrasil.agora().subtract(
                  const Duration(seconds: 1),
                ),
                apiService: api,
                authStorage: _Auth(),
              ),
            ),
          )
          .then((value) => resultado = value),
    );
    await tester.pumpAndSettle();
    expect(api.consultas, 1);
    unawaited(
      principal.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Checkout')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Checkout'), findsOneWidget);
    resposta.complete({'status': 'EXPIRADA', 'segundos_restantes': 0});
    await tester.pumpAndSettle();
    expect(find.text('O tempo para a compra expirou'), findsOneWidget);
    await tester.tap(find.text('VOLTAR'));
    await tester.pumpAndSettle();
    expect(find.text('Checkout'), findsNothing);
    expect(find.byType(EscolhaPagamentoScreen), findsNothing);
    expect(find.text('Participantes'), findsOneWidget);
    expect(principal.currentState!.canPop(), isTrue);
    expect(resultado, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reserva expirada mostra aviso antes de sair', (tester) async {
    final api = _Api()..expirada = true;
    final loja = Loja(
      id: 1,
      organizacaoId: 1,
      nome: 'Loja',
      endereco: '',
      bairro: '',
      cidade: '',
      imagemUrl: '',
      instagram: '',
      vrtaxaprod: 0,
      vrtaxaing: 0,
      dsestiloloja: '',
      nrtelloja: '',
      sgEstado: '',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EscolhaPagamentoScreen(
                    loja: loja,
                    totalProdutos: 0,
                    totalIngressos: 5,
                    reservaIngressoId: 2,
                    reservaExpiracao: HorarioBrasil.agora().subtract(
                      const Duration(seconds: 1),
                    ),
                    apiService: api,
                    authStorage: _Auth(),
                  ),
                ),
              ),
              child: const Text('Abrir pagamento'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir pagamento'));
    await tester.pumpAndSettle();
    expect(find.text('O tempo para a compra expirou'), findsOneWidget);
    expect(find.byType(EscolhaPagamentoScreen), findsOneWidget);
    await tester.tap(find.text('VOLTAR'));
    await tester.pumpAndSettle();
    expect(find.byType(EscolhaPagamentoScreen), findsNothing);
    expect(find.text('Abrir pagamento'), findsOneWidget);
  });
  testWidgets('contador vencido consulta o servidor e preserva reserva ativa', (
    tester,
  ) async {
    final api = _Api();
    final loja = Loja(
      id: 1,
      organizacaoId: 1,
      nome: 'Loja',
      endereco: '',
      bairro: '',
      cidade: '',
      imagemUrl: '',
      instagram: '',
      vrtaxaprod: 0,
      vrtaxaing: 0,
      dsestiloloja: '',
      nrtelloja: '',
      sgEstado: '',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EscolhaPagamentoScreen(
          loja: loja,
          totalProdutos: 0,
          totalIngressos: 5,
          reservaIngressoId: 2,
          reservaExpiracao: HorarioBrasil.agora().subtract(
            const Duration(seconds: 1),
          ),
          apiService: api,
          authStorage: _Auth(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(api.consultas, 1);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            RegExp(r'Tempo para concluir a compra: (30:00|29:59)')
                .hasMatch(widget.data ?? ''),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Sua reserva expirou'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
