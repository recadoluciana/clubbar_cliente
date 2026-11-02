import 'package:clubbar_cliente/models/loja.dart';
import 'package:clubbar_cliente/screens/pagamento/pix_pagamento_screen.dart';
import 'package:clubbar_cliente/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ApiIndisponivel extends ApiService {
  @override
  Future<Map<String, dynamic>> consultarPixPorPagamentoId({
    required String pagamentoId,
  }) async => throw Exception('Sem conexão');
}

class _ApiMercadoPago extends ApiService {
  int consultas = 0;
  bool indisponivel = false;
  String status = 'PENDENTE';

  @override
  Future<Map<String, dynamic>> consultarCheckoutMercadoPago({
    required String preferenceId,
  }) async {
    consultas++;
    if (indisponivel) throw Exception('Sem conexão');
    return {'status': status};
  }
}

class _ApiReservaMercadoPago extends _ApiMercadoPago {
  int consultasReserva = 0;
  bool reservaExpirada = false;

  @override
  Future<Map<String, dynamic>> consultarReserva({
    required int reservaId,
    required int clienteId,
  }) async {
    consultasReserva++;
    return {
      'status_pagamento': 'PENDENTE',
      'status': reservaExpirada ? 'EXPIRADA' : 'AGUARDANDO_PAGAMENTO',
    };
  }
}

Loja _lojaTeste() => Loja(
  id: 1,
  organizacaoId: 1,
  nome: 'Loja teste',
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

Future<void> _abrirPixMercadoPago(
  WidgetTester tester,
  _ApiMercadoPago api, {
  required bool teste,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PixPagamentoScreen(
        loja: _lojaTeste(),
        mercadoPago: true,
        pagamento: {
          'pagamento_id': 'pix-teste',
          'ambiente_teste': teste,
          'expiration_date': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 30))
              .toIso8601String(),
          'pix_copia_cola': 'codigo-teste',
        },
        apiService: api,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('reserva expirada no Pix retorna resultado terminal', (
    tester,
  ) async {
    final api = _ApiReservaMercadoPago()..reservaExpirada = true;
    bool? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                resultado = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PixPagamentoScreen(
                      loja: _lojaTeste(),
                      mercadoPago: true,
                      reservaIngressoId: 2,
                      clienteId: 3,
                      apiService: api,
                      pagamento: {
                        'pagamento_id': 'reserva-pix',
                        'expiration_date': '2020-01-01T00:00:00Z',
                        'pix_copia_cola': 'codigo-teste',
                      },
                    ),
                  ),
                );
              },
              child: const Text('Abrir Pix'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir Pix'));
    await tester.pumpAndSettle();
    expect(find.text('O tempo para a compra expirou'), findsOneWidget);
    await tester.tap(find.text('VOLTAR'));
    await tester.pumpAndSettle();
    expect(resultado, true);
  });
  testWidgets('Pix ainda pendente ao fim do prazo não afirma que expirou', (
    tester,
  ) async {
    final api = _ApiMercadoPago();
    await tester.pumpWidget(
      MaterialApp(
        home: PixPagamentoScreen(
          loja: _lojaTeste(),
          mercadoPago: true,
          apiService: api,
          pagamento: {
            'pagamento_id': 'pix-teste',
            'expiration_date': '2020-01-01T00:00:00Z',
            'pix_copia_cola': 'codigo-teste',
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('O prazo do Pix expirou'), findsNothing);
    expect(
      find.textContaining(
        'a confirmação do pagamento ainda não foi verificada',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Pix expirado mostra aviso e aguarda o cliente voltar', (
    tester,
  ) async {
    final api = _ApiMercadoPago()..status = 'EXPIRED';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PixPagamentoScreen(
                    loja: _lojaTeste(),
                    mercadoPago: true,
                    apiService: api,
                    pagamento: {
                      'pagamento_id': 'pix-teste',
                      'expiration_date': '2020-01-01T00:00:00Z',
                      'pix_copia_cola': 'codigo-teste',
                    },
                  ),
                ),
              ),
              child: const Text('Abrir Pix'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir Pix'));
    await tester.pumpAndSettle();
    expect(find.text('O prazo do Pix expirou'), findsOneWidget);
    expect(find.byType(PixPagamentoScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('O prazo do Pix expirou'), findsOneWidget);
    await tester.tap(find.text('VOLTAR'));
    await tester.pumpAndSettle();
    expect(find.byType(PixPagamentoScreen), findsNothing);
    expect(find.text('Abrir Pix'), findsOneWidget);
  });
  testWidgets('Pix de ingresso consulta a reserva', (tester) async {
    final api = _ApiReservaMercadoPago();
    await tester.pumpWidget(
      MaterialApp(
        home: PixPagamentoScreen(
          loja: _lojaTeste(),
          mercadoPago: true,
          reservaIngressoId: 2,
          clienteId: 3,
          pagamento: {
            'pagamento_id': 'reserva-pix',
            'expiration_date': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 30))
                .toIso8601String(),
            'pix_copia_cola': 'codigo-teste',
          },
          apiService: api,
        ),
      ),
    );
    await tester.pump();
    expect(api.consultasReserva, greaterThan(0));
    expect(api.consultas, 0);
    expect(find.text('Pagamento iniciado'), findsOneWidget);
    expect(find.text('Aguardando pagamento'), findsOneWidget);
    expect(find.textContaining('QR Code Pix expira em'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('informa a limitação do sandbox e mantém o Pix pendente', (
    tester,
  ) async {
    final api = _ApiMercadoPago();
    await _abrirPixMercadoPago(tester, api, teste: true);
    expect(
      find.textContaining('Não use seu banco para pagá-lo.'),
      findsOneWidget,
    );
    final consultasAntes = api.consultas;
    final verificar = find.text('Verificar pagamento agora');
    await tester.ensureVisible(verificar);
    await tester.tap(verificar);
    await tester.pump();
    expect(api.consultas, greaterThan(consultasAntes));
    expect(find.textContaining('O Pix continua pendente.'), findsOneWidget);
    expect(find.byType(PixPagamentoScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('consulta um Pix real sem exibir aviso de sandbox', (
    tester,
  ) async {
    final api = _ApiMercadoPago();
    await _abrirPixMercadoPago(tester, api, teste: false);
    expect(
      find.textContaining('Não use seu banco para pagá-lo.'),
      findsNothing,
    );
    final verificar = find.text('Verificar pagamento agora');
    await tester.ensureVisible(verificar);
    await tester.tap(verificar);
    await tester.pump();
    expect(find.textContaining('sem pagar novamente.'), findsOneWidget);
    expect(find.byType(PixPagamentoScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('falha na consulta manual não informa pagamento confirmado', (
    tester,
  ) async {
    final api = _ApiMercadoPago();
    await _abrirPixMercadoPago(tester, api, teste: false);
    api.indisponivel = true;
    final verificar = find.text('Verificar pagamento agora');
    await tester.ensureVisible(verificar);
    await tester.tap(verificar);
    await tester.pump();
    expect(
      find.textContaining('Não foi possível consultar o pagamento agora.'),
      findsOneWidget,
    );
    expect(find.byType(PixPagamentoScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('não informa expiração quando a verificação falha', (
    tester,
  ) async {
    final loja = Loja(
      id: 1,
      organizacaoId: 1,
      nome: 'Loja teste',
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
        home: PixPagamentoScreen(
          loja: loja,
          pagamento: {
            'pagamento_id': 'pix-teste',
            'expiration_date': '2020-01-01T00:00:00Z',
            'pix_copia_cola': 'codigo-teste',
          },
          apiService: _ApiIndisponivel(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining(
        'a confirmação do pagamento ainda não foi verificada',
      ),
      findsOneWidget,
    );
    expect(find.text('Verificar pagamento agora'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
