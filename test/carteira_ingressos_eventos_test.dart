import 'package:clubbar_cliente/screens/carteira/carteira_ingressos_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Map<String, dynamic> ingresso({
  required int id,
  Object? eventoId,
  String data = '2026-12-13T13:00:00',
  String dataFormatada = '13/12/2026 13:00',
  String modalidade = 'Inteira',
  String setor = 'Pista',
}) => {
  'itvenda_id': id,
  'evento_id': ?eventoId,
  'nmevento': 'Festival',
  'dtinicioevento': data,
  'dtinicioevento_fmt': dataFormatada,
  'endereco_evento_completo': 'Rua do evento, 123',
  'dtcriacao_fmt': '0$id/11/2026 10:00',
  'nmsetor': setor,
  'nmpreco': modalidade,
  'tipopreco': modalidade.toUpperCase(),
  'nmparticipante': 'Participante $id',
  'cpfparticipante': '12345678909',
  'qtitvenda': 1,
  'qrtokenitvenda': 'token-$id',
};

Widget carteira(
  List<Map<String, dynamic>> itens, {
  Future<List<Map<String, dynamic>>> Function()? onAtualizar,
  VoidCallback? onVoltar,
}) => MaterialApp(
  home: CarteiraIngressosScreen(
    nomeLoja: 'Casa',
    logoLoja: '',
    nomeCliente: 'Cliente',
    itens: itens,
    onAtualizar: onAtualizar,
    onVoltar: onVoltar ?? () {},
  ),
);

void telaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('agrupa por ID e preserva cada ingresso e suas ações', (
    tester,
  ) async {
    telaAlta(tester);
    await tester.pumpWidget(
      carteira([
        ingresso(id: 1, eventoId: 10),
        ingresso(id: 2, eventoId: 20, setor: 'VIP'),
        ingresso(id: 3, eventoId: '10', modalidade: 'Cortesia'),
      ]),
    );
    await tester.pump();

    // Mesmo nome, horário e endereço não unem eventos com IDs diferentes.
    expect(find.text('Festival'), findsNWidgets(2));
    expect(find.text('Horário evento'), findsNWidgets(2));
    expect(find.text('Rua do evento, 123'), findsNWidgets(2));
    expect(find.text('2 ingressos'), findsOneWidget);
    expect(find.text('1 ingresso'), findsOneWidget);
    expect(find.byTooltip('Transferir participante'), findsNothing);
    expect(find.text('Presentear'), findsNothing);
    expect(find.text('Exibir QR Code'), findsNothing);

    await tester.tap(find.text('Ver ingressos').first);
    await tester.pumpAndSettle();
    expect(find.text('Meus ingressos'), findsOneWidget);
    expect(find.text('Festival'), findsOneWidget);
    expect(find.byKey(const ValueKey('ingresso-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('ingresso-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('ingresso-2')), findsNothing);
    expect(find.byTooltip('Transferir participante'), findsNWidgets(2));

    for (final id in [1, 3, 2]) {
      if (id == 2) {
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(find.text('Festival'), findsNWidgets(2));
        await tester.tap(find.text('Ver ingressos').last);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('ingresso-1')), findsNothing);
        expect(find.byKey(const ValueKey('ingresso-3')), findsNothing);
      }
      final card = find.byKey(ValueKey('ingresso-$id'));
      expect(
        find.descendant(of: card, matching: find.text('Participante $id')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('0$id/11/2026 10:00')),
        findsOneWidget,
      );
      final qr = find.descendant(
        of: card,
        matching: find.text('Exibir QR Code'),
      );
      await tester.ensureVisible(qr);
      await tester.tap(qr);
      await tester.pumpAndSettle();
      final dialog = find.byType(Dialog);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('Participante: Participante $id'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.text(id == 2 ? 'Setor: VIP' : 'Setor: Pista'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.text(
            id == 3 ? 'Modalidade: Cortesia' : 'Modalidade: Inteira',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'resposta antiga agrupa por evento e data e mantém ordem cronológica',
    (tester) async {
      telaAlta(tester);
      await tester.pumpWidget(
        carteira([
          ingresso(id: 1),
          ingresso(
            id: 2,
            data: '2026-12-12T13:00:00',
            dataFormatada: '12/12/2026 13:00',
          ),
          ingresso(id: 3, modalidade: 'Cortesia'),
        ]),
      );
      await tester.pump();
      expect(find.text('Festival'), findsNWidgets(2));
      expect(find.text('13/12/2026 13:00'), findsOneWidget);
      expect(find.text('12/12/2026 13:00'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('12/12/2026 13:00')).dy,
        lessThan(tester.getTopLeft(find.text('13/12/2026 13:00')).dy),
      );
      expect(find.text('2 ingressos'), findsOneWidget);
      await tester.tap(find.text('Ver ingressos').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ingresso-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('ingresso-1')), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver ingressos').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ingresso-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('ingresso-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('ingresso-2')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'atualização remove grupos vazios e preserva ingressos restantes',
    (tester) async {
      telaAlta(tester);
      await tester.pumpWidget(
        carteira([
          ingresso(id: 1, eventoId: 10),
          ingresso(id: 2, eventoId: 20),
        ], onAtualizar: () async => [ingresso(id: 2, eventoId: 20)]),
      );
      await tester.pump();
      final atualizacao = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await atualizacao;
      expect(find.text('Festival'), findsOneWidget);
      expect(find.byKey(const ValueKey('ingresso-1')), findsNothing);
      expect(find.text('1 ingresso'), findsOneWidget);
      await tester.tap(find.text('Ver ingressos'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ingresso-2')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'atualizar dentro do evento não mostra ingressos de outro evento',
    (tester) async {
      telaAlta(tester);
      await tester.pumpWidget(
        carteira([
          ingresso(id: 1, eventoId: 10),
          ingresso(id: 2, eventoId: 20),
        ], onAtualizar: () async => [ingresso(id: 2, eventoId: 20)]),
      );
      await tester.pump();
      await tester.tap(find.text('Ver ingressos').first);
      await tester.pumpAndSettle();
      final atualizacao = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await atualizacao;
      expect(
        find.text('Não há ingressos disponíveis para este evento.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('ingresso-2')), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Festival'), findsOneWidget);
      expect(find.text('1 ingresso'), findsOneWidget);
      await tester.tap(find.text('Ver ingressos'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ingresso-2')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('voltar pelo sistema retorna primeiro aos eventos', (
    tester,
  ) async {
    telaAlta(tester);
    var saidasDaCarteira = 0;
    await tester.pumpWidget(
      carteira([
        ingresso(id: 1, eventoId: 10),
      ], onVoltar: () => saidasDaCarteira++),
    );
    await tester.pump();
    await tester.tap(find.text('Ver ingressos'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Ver ingressos'), findsOneWidget);
    expect(saidasDaCarteira, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(saidasDaCarteira, 1);
    expect(tester.takeException(), isNull);
  });
}
