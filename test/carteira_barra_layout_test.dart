import 'package:clubbar_cliente/widgets/clubbar_app_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'barra da carteira alinha título à esquerda e atualizar à direita',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: ClubbarAppBar(
              titulo: 'Minha Carteira',
              iconeTitulo: Icons.account_balance_wallet_rounded,
              mostrarVoltar: true,
              mostrarLogo: false,
              mostrarSessao: false,
              tituloAlinhadoEsquerda: true,
              actions: [
                IconButton(
                  onPressed: () {},
                  tooltip: 'Atualizar carteira',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
        ),
      );
      final voltar = tester.getRect(find.byIcon(Icons.arrow_back));
      final carteira = tester.getRect(
        find.byIcon(Icons.account_balance_wallet_rounded),
      );
      final titulo = tester.getRect(find.text('Minha Carteira'));
      final atualizar = tester.getRect(find.byTooltip('Atualizar carteira'));
      expect(voltar.right, lessThan(carteira.left));
      expect(carteira.right, lessThan(titulo.left));
      expect(titulo.right, lessThan(atualizar.left));
      expect(atualizar.right, closeTo(360, 8));
      expect(tester.takeException(), isNull);
    },
  );
}
