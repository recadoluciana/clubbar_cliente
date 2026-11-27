import 'dart:convert';
import 'package:clubbar_cliente/models/loja.dart';
import 'package:clubbar_cliente/utils/value_formatters.dart';
import 'package:clubbar_cliente/screens/produtos_loja/produtos_loja_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final tipo in ['PACOTE', 'PERCENTUAL']) {
    testWidgets('opções de $tipo enviam campanha apenas para promoção', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'cliente_id': 1});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => 'token');
      final enviados = <Map<String, dynamic>>[];
      final cliente = MockClient((request) async {
        final path = request.url.path;
        Object data = <String, dynamic>{};
        if (path.endsWith('/cardapio-publicado')) {
          data = {'vendas_habilitadas': true, 'categorias': [
            {'categoria_id': 1, 'nmcategoria': 'Bebidas', 'itens': [
              {'produto_id': 10, 'cardapioitem_id': 11, 'categoria_id': 1,
               'loja_id': 2, 'organizacao_id': 1, 'nmproduto': 'Produto teste',
               'dsproduto': '', 'sitproduto': 'ATIVO', 'vrprecoprod': 9.0}
            ]}
          ]};
        } else if (path.endsWith('/ofertas')) {
          data = [{'produto_id': 10, 'tipo': tipo, 'campanha_id': 42,
            'qtitenspacote': 3, 'vrpacote': 24, 'percentual_desconto': 10}];
        } else if (path == '/entregas/pendentes') {
          data = [];
        } else if (path == '/carrinho/itens') {
          data = {'itens': []};
        } else if (path == '/carrinho/qtde_itens_geral') {
          data = {'qt_total': 0};
        } else if (path == '/carrinho/adicionar') {
          enviados.add(Map<String, dynamic>.from(jsonDecode(request.body)));
        }
        return http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'});
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(home: ProdutosLojaScreen(
          loja: Loja.fromJson({'loja_id': 2, 'organizacao_id': 1, 'nmloja': 'Teste'}))));
        await tester.pumpAndSettle();
        expect(find.text('Produto teste'), findsOneWidget);
        expect(find.text(tipo == 'PACOTE' ? 'Promoção: 3 por ${ValueFormatters.moeda(24)}' : 'Promoção: 10% OFF · ${ValueFormatters.moeda(8.1)}/un'), findsOneWidget);
        expect(find.text(ValueFormatters.moeda(9)), findsOneWidget);
        final vermelho = find.byWidgetPredicate((widget) => widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == const Color(0xFFE57373));
        final amarelo = find.byWidgetPredicate((widget) => widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == const Color(0xFFFFD166));
        if (tipo == 'PACOTE') {
          expect(find.widgetWithText(TextButton, 'Adicionar'), findsNWidgets(2));
          expect(tester.getSize(vermelho.first).height, tester.getSize(amarelo.first).height);
          final textosAdicionar = find.text('Adicionar');
          expect(tester.getSize(textosAdicionar.first), tester.getSize(textosAdicionar.last));
          await tester.tap(find.widgetWithText(TextButton, 'Adicionar').first);
          await tester.pumpAndSettle();
          expect(enviados.last['campanha_id'], 42);
          expect(enviados.last['qt'], 1);
          ScaffoldMessenger.of(tester.element(find.text('Produto teste'))).hideCurrentSnackBar();
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Aumentar quantidade'));
          await tester.pump();
          await tester.tap(find.widgetWithText(TextButton, 'Adicionar').last);
          await tester.pumpAndSettle();
          expect(enviados.last['campanha_id'], isNull);
          expect(enviados.last['qt'], 2);
        } else {
          expect(find.widgetWithText(TextButton, 'Adicionar'), findsOneWidget);
          expect(amarelo, findsNothing);
          expect(tester.getCenter(find.byTooltip('Aumentar quantidade')).dy,
            closeTo(tester.getCenter(find.text('Adicionar')).dy, 1));
          expect(tester.getCenter(find.byTooltip('Aumentar quantidade')).dx,
            lessThan(tester.getCenter(find.text('Adicionar')).dx));
          await tester.tap(find.byTooltip('Aumentar quantidade'));
          await tester.pump();
          await tester.tap(find.widgetWithText(TextButton, 'Adicionar'));
          await tester.pumpAndSettle();
          expect(enviados.last['campanha_id'], 42);
          expect(enviados.last['qt'], 2);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => cliente);
    });
  }
}
