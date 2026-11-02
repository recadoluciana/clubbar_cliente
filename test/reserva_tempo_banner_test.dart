import 'package:clubbar_cliente/widgets/reserva_tempo_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mostra e atualiza o tempo restante da reserva', (tester) async {
    final tempo = ValueNotifier(const Duration(minutes: 35));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReservaTempoBanner(tempo: tempo)),
      ),
    );
    expect(find.text('Tempo restante da reserva: 35:00'), findsOneWidget);
    tempo.value = const Duration(minutes: 2, seconds: 9);
    await tester.pump();
    expect(find.text('Tempo restante da reserva: 02:09'), findsOneWidget);
    tempo.value = Duration.zero;
    await tester.pump();
    expect(find.text('Tempo restante da reserva: 00:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    tempo.dispose();
  });
}
