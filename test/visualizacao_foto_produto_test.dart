import 'package:clubbar_cliente/screens/produtos_loja/produto_compartilhado_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('foto permite aumentar e diminuir o zoom', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VisualizacaoFotoProduto(
            url: 'https://example.invalid/foto.png',
          ),
        ),
      ),
    );
    await tester.pump();
    final controle = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    expect(controle.value.getMaxScaleOnAxis(), 1);
    await tester.tap(find.byTooltip('Aumentar foto'));
    await tester.pump();
    expect(controle.value.getMaxScaleOnAxis(), 1.5);
    await tester.tap(find.byTooltip('Diminuir foto'));
    await tester.pump();
    expect(controle.value.getMaxScaleOnAxis(), 1);
  });
}
