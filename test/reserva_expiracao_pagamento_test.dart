import 'package:clubbar_cliente/models/loja.dart';
import 'package:clubbar_cliente/screens/pagamento/escolha_pagamento_screen.dart';
import 'package:clubbar_cliente/services/api_service.dart';
import 'package:clubbar_cliente/services/auth_storage.dart';
import 'package:clubbar_cliente/utils/horario_brasil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends AuthStorage {
  @override
  Future<int?> obterClienteId() async => 3;
}

class _Api extends ApiService {
  int consultas = 0;
  bool expirada = false;

  @override
  Future<Map<String, dynamic>> consultarReserva({
    required int reservaId,
    required int clienteId,
  }) async {
    consultas++;
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
      find.byWidgetPredicate((widget) => widget is Text &&
          RegExp(r'Tempo para concluir a compra: (30:00|29:59)')
              .hasMatch(widget.data ?? '')),
      findsOneWidget,
    );
    expect(find.textContaining('Sua reserva expirou'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
