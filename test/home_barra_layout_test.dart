import 'package:clubbar_cliente/widgets/clubbar_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final logado in [true, false]) {
    testWidgets('marca, sessão e coruja na barra inicial (logado: $logado)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'nmcliente': 'Recadoluciana'});
      const canal = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      final canais = tester.binding.defaultBinaryMessenger;
      canais.setMockMethodCallHandler(
        canal,
        (_) async => logado ? 'token' : null,
      );
      addTearDown(() => canais.setMockMethodCallHandler(canal, null));
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      for (final largura in [320.0, 500.0]) {
        tester.view.physicalSize = Size(largura, 850);
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(appBar: ClubbarAppBar.inicio())),
        );
        await tester.pumpAndSettle();
        final barra = find.byType(ClubbarAppBar);
        expect(
          find.descendant(of: barra, matching: find.text('Home')),
          findsNothing,
        );
        expect(
          find.descendant(of: barra, matching: find.byIcon(Icons.home_rounded)),
          findsNothing,
        );
        final marca = tester.getRect(find.bySemanticsLabel('Clubbar'));
        final sessao = tester.getRect(
          find.text(logado ? 'Recadoluciana' : 'Login').hitTestable(),
        );
        final coruja = tester.getRect(
          find.descendant(
            of: barra,
            matching: find.image(const AssetImage('assets/images/corujao.png')),
          ),
        );
        expect(coruja.left, closeTo(16, 1));
        expect(coruja.right, lessThan(marca.left));
        expect(marca.right, lessThan(sessao.left));
        if (logado) {
          final icone = tester.widget<Icon>(find.byIcon(Icons.person_rounded));
          expect(icone.color, Colors.amber);
          expect(tester.getRect(find.byIcon(Icons.person_rounded)).right,
              lessThan(sessao.left));
          if (largura == 500) expect(sessao.width, greaterThan(80));
        }
      }
    });
  }
}
