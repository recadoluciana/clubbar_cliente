import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/cart_badge_notifier.dart';
import '../../services/carteira_badge_notifier.dart';
import '../../services/auth_storage.dart';
import '../../services/main_navigation_controller.dart';

class PagamentoSucessoScreen extends StatefulWidget {
  const PagamentoSucessoScreen({super.key});

  @override
  State<PagamentoSucessoScreen> createState() => _PagamentoSucessoScreenState();
}

class _PagamentoSucessoScreenState extends State<PagamentoSucessoScreen> {
  @override
  void initState() {
    super.initState();
    _atualizarBadges();
  }

  Future<void> _atualizarBadges() async {
    try {
      final clienteId = await AuthStorage().obterClienteId();

      if (clienteId == null || clienteId == 0) return;

      final qtdCarrinho = await ApiService().buscarQuantidadeCarrinho(
        clienteId: clienteId,
      );

      CartBadgeNotifier.atualizar(qtdCarrinho);

      // força atualização da carteira
      CarteiraBadgeNotifier.atualizar();
    } catch (e) {
      debugPrint('Erro ao atualizar badges: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Pagamento realizado com sucesso',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 10),

                Text(
                  'Sua compra foi confirmada. Você já pode acompanhar pela sua carteira.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 26),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      MainNavigationController.irParaHome();

                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Home',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
