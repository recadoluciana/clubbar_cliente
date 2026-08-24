import 'package:flutter/material.dart';

import '../screens/login/login_screen.dart';
import 'app_snackbar.dart';

Future<void> direcionarParaLogin(
  BuildContext context, {
  String mensagem = 'Faça login para continuar.',
}) async {
  AppSnackBar.info(context, mensagem);
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
}
