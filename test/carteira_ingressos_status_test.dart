import 'package:clubbar_cliente/screens/carteira/carteira_ingressos_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('diálogo do QR usa a cor da modalidade', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
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
              'nmproduto': 'Cortesia',
              'tipopreco': 'CORTESIA',
              'qrtokenitvenda': 'um',
              'qtitvenda': 1,
            },
            {
              'nmproduto': 'Inteira',
              'tipopreco': 'INTEIRA',
              'qrtokenitvenda': 'dois',
              'qtitvenda': 1,
            },
          ],
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Exibir QR Code').at(i));
      await tester.pumpAndSettle();
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      final cor = i == 0 ? Colors.green.shade700 : Colors.blue.shade700;
      expect((dialog.shape as RoundedRectangleBorder).side.color, cor);
      final cabecalho = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Container),
        ),
      );
      expect(
        cabecalho.any(
          (container) => container.color == cor,
        ),
        isTrue,
      );
      final participante = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.text('Participante: Não informado'),
              matching: find.byType(Container),
            ),
          )
          .firstWhere(
            (container) =>
                (container.decoration as BoxDecoration?)?.border != null,
          );
      final decoracao = participante.decoration as BoxDecoration;
      expect(decoracao.color, cor.withValues(alpha: 0.08));
      expect(
        (decoracao.border as Border).top.color,
        cor.withValues(alpha: 0.35),
      );
      final botao = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Voltar'),
      );
      expect(botao.style?.backgroundColor?.resolve({}), cor);
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('borda e modalidade seguem o tipo de ingresso', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
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
              'nmproduto': 'Ingresso cortesia',
              'nmpreco': 'Cortesia',
              'tipopreco': 'CORTESIA',
              'qtitvenda': 1,
            },
            {
              'nmproduto': 'Ingresso meia',
              'nmpreco': 'Meia-entrada',
              'tipopreco': 'MEIA',
              'qtitvenda': 1,
            },
            {
              'nmproduto': 'Ingresso legado',
              'nmpreco': 'Inteira',
              'tipopreco': 'INTEIRA',
              'tipo_ingresso': 'Pista • Cortesia',
              'nmsetor': 'Pista',
              'qtitvenda': 1,
            },
          ],
        ),
      ),
    );
    await tester.pump();
    Color corBorda(String nome) {
      final materiais = tester.widgetList<Material>(
        find.ancestor(of: find.text(nome), matching: find.byType(Material)),
      );
      final cartao = materiais.firstWhere(
        (m) =>
            m.shape is RoundedRectangleBorder &&
            (m.shape as RoundedRectangleBorder).side.width == 1.5,
      );
      return (cartao.shape as RoundedRectangleBorder).side.color;
    }

    expect(corBorda('Ingresso cortesia'), Colors.green.shade700);
    expect(corBorda('Ingresso meia'), Colors.blue.shade700);
    expect(corBorda('Ingresso legado'), Colors.green.shade700);
    final iconesParticipante = tester
        .widgetList<Icon>(find.byIcon(Icons.person_rounded))
        .map((icon) => icon.color)
        .toList();
    expect(iconesParticipante, [
      Colors.green.shade700,
      Colors.blue.shade700,
      Colors.green.shade700,
    ]);
    expect(
      tester
          .widgetList<Text>(find.text('Cortesia'))
          .every((t) => t.style?.color == Colors.green.shade700),
      isTrue,
    );
    expect(
      tester.widget<Text>(find.text('Meia-entrada')).style?.color,
      Colors.blue.shade700,
    );
    final presentear = tester
        .widgetList<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Presentear'),
        )
        .toList();
    final qr = tester
        .widgetList<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Exibir QR Code'),
        )
        .toList();
    for (var i = 0; i < 3; i++) {
      final cor = i == 1 ? Colors.blue.shade700 : Colors.green.shade700;
      expect(presentear[i].style?.foregroundColor?.resolve({}), cor);
      expect(presentear[i].style?.side?.resolve({})?.color, cor);
      expect(qr[i].style?.backgroundColor?.resolve({}), cor);
    }
  });

  testWidgets('ação do participante fica à direita e presentear à esquerda', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
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
              'nmproduto': 'Evento',
              'nmparticipante': 'Ana Beatriz de Oliveira Silva',
              'cpfparticipante': '12345678909',
              'qtitvenda': 1,
            },
          ],
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text(
        '1 ingresso disponível\nApresente o QR Code na portaria do evento',
      ),
      findsOneWidget,
    );
    final nome = find.text('Ana Beatriz de Oliveira Silva');
    final cpf = find.text('CPF: 123.456.789-09');
    final acao = find.widgetWithText(OutlinedButton, 'Transferir');
    expect(nome, findsOneWidget);
    expect(cpf, findsOneWidget);
    expect(acao, findsOneWidget);
    expect(tester.getRect(acao).left, greaterThan(tester.getRect(nome).right));
    expect(tester.getSize(acao).width, tester.getSize(acao).height);
    expect(
      tester.getTopLeft(find.text('Presentear')).dx,
      lessThan(tester.getTopLeft(find.text('Exibir QR Code')).dx),
    );
    expect(tester.takeException(), isNull);
  });

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
      expect(find.text('Horário'), findsOneWidget);
      expect(find.text('13/12/2026\n13:00'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Horário')).dx,
        lessThan(tester.getTopLeft(find.text('Local')).dx),
      );
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
