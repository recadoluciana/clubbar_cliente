import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';

import 'app.dart';
import 'services/auth_storage.dart';
import 'services/notificacoes_promocionais.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  runApp(const ClubbarApp());
  unawaited(_restaurarNotificacoes());
}

Future<void> _restaurarNotificacoes() async {
  try {
    final token = await AuthStorage().obterToken();
    if (token != null && token.isNotEmpty) {
      await NotificacoesPromocionais.instance.ativar(token);
    }
  } catch (_) {
    // O aplicativo pode ser usado normalmente se as notificações falharem.
  }
}
