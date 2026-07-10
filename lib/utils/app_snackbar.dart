import 'package:flutter/material.dart';

class AppSnackBar {
  static void sucesso(BuildContext context, String mensagem) {
    _mostrar(
      context,
      mensagem,
      Colors.green.shade700,
      Colors.white,
      Icons.check_circle_rounded,
    );
  }

  static void erro(BuildContext context, String mensagem) {
    _mostrar(
      context,
      mensagem,
      Colors.red.shade700,
      Colors.white,
      Icons.error_rounded,
    );
  }

  static void aviso(BuildContext context, String mensagem) {
    _mostrar(
      context,
      mensagem,
      Colors.amber.shade700,
      Colors.black,
      Icons.warning_amber_rounded,
    );
  }

  static void info(BuildContext context, String mensagem) {
    _mostrar(
      context,
      mensagem,
      Colors.blue.shade700,
      Colors.white,
      Icons.info_rounded,
    );
  }

  static void _mostrar(
    BuildContext context,
    String mensagem,
    Color backgroundColor,
    Color foregroundColor,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.fixed,
        elevation: 6,
        duration: const Duration(seconds: 4),
        backgroundColor: backgroundColor,
        content: Row(
          children: [
            Icon(icon, color: foregroundColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensagem,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
