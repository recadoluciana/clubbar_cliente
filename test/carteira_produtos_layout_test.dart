import 'package:clubbar_cliente/screens/carteira/carteira_loja_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('agrupa produtos e usa o QR da unidade escolhida', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(450, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final itens = [
      {
        'itvenda_id': 1,
        'produto_id': 5,
        'nmproduto': 'Cerveja',
        'qtitvenda': 1,
        'vrunititvenda': 3,
        'qrtokenitvenda': 'primeiro',
        'dtexpiraitvenda_fmt': '20/12/2026',
      },
      {
        'itvenda_id': 2,
        'produto_id': 5,
        'nmproduto': 'Cerveja',
        'qtitvenda': 1,
        'vrunititvenda': 3,
        'qrtokenitvenda': 'segundo',
        'dtexpiraitvenda_fmt': '10/12/2026',
      },
      {
        'itvenda_id': 3,
        'produto_id': 5,
        'nmproduto': 'Cerveja',
        'qtitvenda': 1,
        'vrunititvenda': 0,
        'qrtokenitvenda': 'cortesia',
        'dtexpiraitvenda_fmt': '30/12/2026',
      },
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: CarteiraLojaScreen(
          nomeLoja: 'Loja',
          logoLoja: '',
          nomeCliente: 'Cliente',
          itens: itens,
          onAtualizar: () async => [itens.first],
          onVoltar: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Cerveja'), findsOneWidget);
    expect(find.text('3 unidades disponíveis'), findsOneWidget);
    expect(find.text('1 cortesia'), findsOneWidget);
    expect(find.text('Próxima validade: 10/12/2026'), findsOneWidget);
    await tester.tap(find.text('Presentear'));
    await tester.pumpAndSettle();
    expect(find.text('Escolha uma unidade para presentear'), findsOneWidget);
    await tester.tap(find.text('Unidade 2'));
    await tester.pumpAndSettle();
    expect(find.text('Enviar como presente'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exibir QR Code'));
    await tester.pumpAndSettle();
    expect(find.text('Unidade 1'), findsOneWidget);
    expect(find.text('Unidade 2'), findsOneWidget);
    expect(find.text('Unidade 3'), findsOneWidget);
    expect(find.text('Válido até 30/12/2026 • Cortesia'), findsOneWidget);
    await tester.tap(find.text('Unidade 1'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<QrImageView>(find.byType(QrImageView)).key,
      const ValueKey('CLUBBAR-PRODUTO:segundo'),
    );
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('1 unidade disponível'), findsOneWidget);
  });

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
    expect(find.text('Cortesia'), findsOneWidget);
    expect(find.text('Saiu para entrega'), findsOneWidget);
    expect(find.text('Exibir QR Code de entrega'), findsOneWidget);
    expect(
      find.text('Pagamento realizado. Apresente o QR Code ao motoboy.'),
      findsOneWidget,
    );
  });
}
