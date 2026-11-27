import 'dart:convert';

import 'package:clubbar_cliente/models/loja.dart';
import 'package:clubbar_cliente/screens/detalhe_evento/participantes_reserva_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('excluir um ingresso preserva os dados do outro', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'cliente_id': 1});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => 'token');
    final removidos = <int>[];
    final client = MockClient((request) async => http.Response(jsonEncode({'ok': true}), 200));
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: ParticipantesReservaScreen(
        loja: Loja.fromJson({'loja_id': 5, 'organizacao_id': 1, 'nmloja': 'Casa'}),
        nomeEvento: 'Festival', dataHoraEvento: '13/12/2026 13:00',
        nomeLote: 'Lote', nomeSetor: 'Setor', modalidade: 'Inteira',
        reserva: {
          'reserva_ingresso_id': 30, 'compra_evento_id': 20, 'cliente_id': 1,
          'segundos_restantes': 900, 'quantidade': 2, 'valor_total': 66,
          'itens': [
            {'reserva_ingresso_id': 30, 'quantidade': 1, 'valor_total': 33, 'nome_modalidade': 'Inteira'},
            {'reserva_ingresso_id': 31, 'quantidade': 1, 'valor_total': 33, 'nome_modalidade': 'Inteira'},
          ],
        },
        onRemoverIngresso: (item) async => removidos.add(item['reserva_ingresso_id'] as int),
      )));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Nome completo').at(0), 'Primeira Pessoa');
      await tester.enterText(find.widgetWithText(TextField, 'Nome completo').at(1), 'Segunda Pessoa');
      await tester.tap(find.byTooltip('Excluir ingresso').first);
      await tester.pump();
      expect(removidos, [30]);
      expect(find.text('Segunda Pessoa'), findsOneWidget);
      expect(find.text('Primeira Pessoa'), findsNothing);
      expect(find.byTooltip('Excluir ingresso'), findsOneWidget);
      expect(find.textContaining('33,00'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });
}