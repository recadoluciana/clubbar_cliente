import 'dart:convert';

import 'package:clubbar_cliente/models/loja.dart';
import 'package:clubbar_cliente/screens/detalhe_loja/detalhe_loja_screen.dart';
import 'package:clubbar_cliente/screens/pagamento/pagamento_sucesso_screen.dart';
import 'package:clubbar_cliente/screens/produtos_loja/produtos_loja_screen.dart';
import 'package:clubbar_cliente/services/main_navigation_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final verCardapio in [true, false]) {
    testWidgets('pagamento concluído abre ${verCardapio ? 'cardápio' : 'loja'}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      MainNavigationController.limparTelasInternas();
      addTearDown(MainNavigationController.limparTelasInternas);
      final loja = Loja.fromJson({
        'loja_id': 2,
        'organizacao_id': 1,
        'nmloja': 'Loja teste',
      });
      final cliente = MockClient((_) async => http.Response(
        jsonEncode(<String, dynamic>{}),
        200,
        headers: {'content-type': 'application/json'},
      ));
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: PagamentoSucessoScreen(lojaDestino: loja),
        ));
        await tester.pump();
        expect(find.text('Pagamento realizado com sucesso'), findsOneWidget);
        expect(find.text('Sim, ver cardápio'), findsOneWidget);
        expect(find.text('Não, voltar para a loja'), findsOneWidget);
        final opcao = find.text(verCardapio ? 'Sim, ver cardápio' : 'Não, voltar para a loja');
        await tester.ensureVisible(opcao);
        await tester.pump();
        await tester.tap(opcao);
        expect(
          MainNavigationController.telaInterna.value,
          verCardapio ? isA<ProdutosLojaScreen>() : isA<DetalheLojaScreen>(),
        );
        if (verCardapio) {
          MainNavigationController.fecharTelaInterna();
          expect(MainNavigationController.telaInterna.value, isA<DetalheLojaScreen>());
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => cliente);
    });
  }
}
