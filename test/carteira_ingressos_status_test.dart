import 'package:clubbar_cliente/screens/carteira/carteira_ingressos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ingresso mostra modalidade, local e data do evento sem dados da compra',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: CarteiraIngressosScreen(
            nomeLoja: 'Loja',
            logoLoja: '',
            nomeCliente: 'Cliente',
            onAtualizar: null,
            onVoltar: () {},
            itens: [
              {
                'nmproduto': 'Festival',
                'lote': 'Lote 1',
                'nmsetor': 'Pista',
                'nmpreco': 'Meia-entrada',
                'tipo_ingresso': 'Pista • Meia-entrada • Estudante',
                'endereco_evento_completo': 'Rua do evento, 123',
                'dtinicioevento_fmt': '13/12/2026 13:00',
                'dtcriacao_fmt': '06/11/2026 15:57',
                'vrunititvenda': 2.50,
                'qtitvenda': 1,
              },
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Festival'), findsOneWidget);
      expect(find.text('Meia-entrada • Estudante'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);
      expect(find.text('Rua do evento, 123'), findsOneWidget);
      expect(find.text('Data e hora do evento'), findsOneWidget);
      expect(find.text('13/12/2026 13:00'), findsOneWidget);
      for (final texto in [
        'Lote 1',
        'Pista',
        'Data e hora da compra',
        '06/11/2026 15:57',
        'Valor',
        'R\$ 2,50',
        'Pago',
      ]) {
        expect(find.text(texto), findsNothing);
      }
      expect(find.text('Exibir QR Code'), findsOneWidget);
      expect(find.text('Presentear'), findsOneWidget);
    },
  );

  testWidgets(
    'dados ausentes informam que local e data não estão disponíveis',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CarteiraIngressosScreen(
            nomeLoja: 'Loja',
            logoLoja: '',
            nomeCliente: 'Cliente',
            onAtualizar: null,
            onVoltar: () {},
            itens: [
              {'nmproduto': 'Evento', 'nmpreco': 'Cortesia', 'qtitvenda': 1},
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Cortesia'), findsOneWidget);
      expect(find.text('Não informado'), findsOneWidget);
      expect(find.text('Não informada'), findsOneWidget);
    },
  );
}
