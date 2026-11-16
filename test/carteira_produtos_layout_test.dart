import 'package:clubbar_cliente/screens/carteira/carteira_loja_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exibe orientação uma vez e preserva validade e entrega', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CarteiraLojaScreen(
          nomeLoja: 'Loja',
          logoLoja: '',
          nomeCliente: 'Cliente',
          onAtualizar: null,
          onVoltar: () {},
          itens: [
            {
              'itvenda_id': 1,
              'nmproduto': 'Produto A',
              'qtitvenda': 1,
              'vrunititvenda': 3,
              'dtcriacao_fmt': '15/11/2026 22:00',
              'dtexpiraitvenda_fmt': '07/02/2027',
            },
            {
              'itvenda_id': 2,
              'nmproduto': 'Produto B',
              'qtitvenda': 1,
              'vrunititvenda': 0,
              'dtexpiraitvenda_fmt': '08/02/2027',
            },
            {
              'itvenda_id': 3,
              'nmproduto': 'Entrega',
              'qtitvenda': 1,
              'tipo_operacao': 'DELIVERY',
              'situacaoentrega': 'EM_ROTA',
              'situacaovenda': 'PAGA',
            },
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Apresente o QR Code para o atendente'), findsOneWidget);
    expect(find.text('Válido até 07/02/2027'), findsOneWidget);
    expect(find.text('Válido até 08/02/2027'), findsOneWidget);
    expect(find.text('Exibir QR Code'), findsNWidgets(2));
    expect(find.text('Presentear'), findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      final cor = i == 0 ? Colors.blue.shade700 : Colors.green.shade700;
      final titulo = find.text(i == 0 ? 'Produto A' : 'Produto B');
      final card = tester
          .widgetList<Material>(
            find.ancestor(of: titulo, matching: find.byType(Material)),
          )
          .firstWhere(
            (material) =>
                material.shape is RoundedRectangleBorder &&
                (material.shape as RoundedRectangleBorder).side.width == 1.5,
          );
      expect((card.shape as RoundedRectangleBorder).side.color, cor);
      final presentear = find.widgetWithText(TextButton, 'Presentear').at(i);
      final qr = find.widgetWithText(ElevatedButton, 'Exibir QR Code').at(i);
      expect(
        tester
            .widget<TextButton>(presentear)
            .style
            ?.foregroundColor
            ?.resolve({}),
        cor,
      );
      expect(
        tester.widget<ElevatedButton>(qr).style?.backgroundColor?.resolve({}),
        Colors.amber,
      );
      expect(
        tester.getTopLeft(presentear).dx,
        lessThan(tester.getTopLeft(qr).dx),
      );
    }
    expect(find.textContaining('Data da compra:'), findsNothing);
    expect(find.textContaining('Valor:'), findsNothing);
    expect(find.text('Cortesia'), findsNothing);
    expect(find.text('Saiu para entrega'), findsOneWidget);
    expect(find.text('Exibir QR Code de entrega'), findsOneWidget);
    expect(
      find.text('Pagamento realizado. Apresente o QR Code ao motoboy.'),
      findsOneWidget,
    );
  });
}
