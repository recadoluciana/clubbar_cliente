import 'dart:convert';
import 'package:clubbar_cliente/models/loja.dart';
import 'package:clubbar_cliente/utils/value_formatters.dart';
import 'package:clubbar_cliente/screens/carrinho/carrinho_screen.dart';
import 'package:clubbar_cliente/screens/produtos_loja/produtos_loja_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('giro usa prêmio da API ao adicionar uma unidade', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
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
            {'produto_id': 10, 'cardapioitem_id': 11, 'categoria_id': 1, 'loja_id': 2,
             'organizacao_id': 1, 'nmproduto': 'Produto teste', 'dsproduto': '',
             'sitproduto': 'ATIVO', 'vrprecoprod': 9.0}
          ]}
        ]};
      } else if (path.endsWith('/ofertas')) {
        data = [{'produto_id': 10, 'tipo': 'ROLETA', 'campanha_id': 42}];
      } else if (path.endsWith('/girar')) {
        data = {'resgate_id': 77, 'percentual_desconto': 20};
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
      await tester.tap(find.text('Gire a roleta'));
      await tester.pumpAndSettle();
      expect(find.text('Você ganhou 20% de desconto!'), findsOneWidget);
      await tester.tap(find.text('Usar desconto'));
      await tester.pumpAndSettle();
      expect(enviados.single['beneficio_resgate_id'], 77);
      expect(enviados.single['qt'], 1);
      expect(enviados.single['campanha_id'], isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => cliente);
  });
  testWidgets('prêmio fica separado e não permite aumentar quantidade', (tester) async {
    SharedPreferences.setMockInitialValues({'cliente_id': 1});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => 'token');
    final cliente = MockClient((request) async {
      Object data = <String, dynamic>{};
      if (request.url.path == '/carrinho/itens') {
        data = {'carrinho_id': 10, 'itens': [
          {'itcarrinho_id': 1, 'produto_id': 10, 'cardapioitem_id': 11,
           'beneficio_resgate_id': 77, 'valor_economia': 2.2, 'nmproduto': 'Produto teste', 'qt': 1,
           'vrprecoprod': 7.2, 'vrprecofinal': 7.2, 'idtipoproduto': 'P'},
          {'itcarrinho_id': 2, 'produto_id': 10, 'cardapioitem_id': 11,
           'nmproduto': 'Produto teste', 'qt': 1, 'vrprecoprod': 9,
           'vrprecofinal': 9, 'idtipoproduto': 'P'},
        ]};
      }
      return http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'});
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: CarrinhoScreen(
        loja: Loja.fromJson({'loja_id': 2, 'organizacao_id': 1, 'nmloja': 'Teste'}))));
      await tester.pumpAndSettle();
      expect(find.text('Produto teste'), findsNWidgets(2));
      expect(find.text('Economizou '+ValueFormatters.moeda(2.2)), findsOneWidget);
      expect(tester.getTopLeft(find.text('2 itens no carrinho')).dy, lessThan(tester.getTopLeft(find.text('Produto teste').first).dy));
      final premio = find.byTooltip('Desconto da roleta válido para uma unidade');
      expect(premio, findsOneWidget);
      expect(tester.widget<IconButton>(find.ancestor(of: premio, matching: find.byType(IconButton)).first).onPressed, isNull);
      expect(find.byTooltip('Aumentar quantidade'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => cliente);
  });

}
