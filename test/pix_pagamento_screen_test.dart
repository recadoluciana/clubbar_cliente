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

  @override
  Future<Map<String, dynamic>> consultarCheckoutMercadoPago({
    required String preferenceId,
  }) async {
    consultas++;
    if (indisponivel) throw Exception('Sem conexão');
    return {'status': 'PENDENTE'};
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
