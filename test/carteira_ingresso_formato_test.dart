import 'package:clubbar_cliente/screens/carteira/carteira_ingressos_screen.dart';
import 'package:clubbar_cliente/utils/value_formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  for (final largura in [320.0, 500.0]) {
    testWidgets('ingresso exibe dados e ações na largura $largura', (
      tester,
    ) async {
      tester.view.physicalSize = Size(largura, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: CarteiraIngressosScreen(
            nomeLoja: 'Casa',
            logoLoja: '',
            nomeCliente: 'Cliente',
            onAtualizar: null,
            onVoltar: () {},
            itens: const [
              {
                'itvenda_id': 1,
                'nmevento': 'Festival',
                'nmpreco': 'Inteira',
                'nmsetor': 'Pista',
                'dtinicioevento_fmt': '13/12/2026 13:00',
                'dtcriacao_fmt': '06/11/2026 15:57',
                'nmparticipante': 'Ana Beatriz',
                'cpfparticipante': '12345678909',
                'qtitvenda': 1,
                'vrunititvenda': 10,
                'vrtaxaitvenda': 2.99,
                'qrtokenitvenda': 'token-teste',
              },
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Festival'), findsOneWidget);
      expect(find.text('Setor: Pista'), findsOneWidget);
      expect(find.text('13/12/2026\n13:00'), findsOneWidget);
      expect(find.text('06/11/2026 15:57'), findsOneWidget);
      expect(find.text('Ana Beatriz'), findsOneWidget);
      expect(find.text('CPF: 123.456.789-09'), findsOneWidget);
      expect(find.text(ValueFormatters.moeda(12.99)), findsOneWidget);
      expect(find.text('Transferir participante'), findsOneWidget);
      expect(find.text('Presentear alguém'), findsOneWidget);
      expect(find.text('Exibir QR Code'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Exibir QR Code'));
      await tester.tap(find.text('Exibir QR Code'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Participante: Ana Beatriz'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
