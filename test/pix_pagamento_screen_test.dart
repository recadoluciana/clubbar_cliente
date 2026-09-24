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

void main() {
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
  });
}
