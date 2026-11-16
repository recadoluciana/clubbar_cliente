import 'package:clubbar_cliente/screens/carteira/carteira_ingressos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('valor determina selo e cortesia do lote não aparece em azul', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
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
              'nmproduto': 'Ingresso pago',
              'lote': 'Cortesia',
              'nmpreco': 'Meia-entrada',
              'vrunititvenda': 2.50,
              'qtitvenda': 1,
            },
            {
              'nmproduto': 'Ingresso gratuito',
              'lote': 'Cortesia',
              'nmpreco': 'Cortesia',
              'vrunititvenda': 0,
              'qtitvenda': 1,
            },
            {
              'nmproduto': 'Valor ausente',
              'vrunititvenda': null,
              'qtitvenda': 1,
            },
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Pago'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'Cortesia',
      ),
      findsOneWidget,
    );
    expect(find.text('Não informado'), findsOneWidget);
    expect(
      find.textContaining('Meia-entrada', findRichText: true),
      findsOneWidget,
    );
    final detalhePago = tester.widget<RichText>(
      find.textContaining('Meia-entrada', findRichText: true),
    );
    expect(detalhePago.text.toPlainText(), 'Meia-entrada');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
