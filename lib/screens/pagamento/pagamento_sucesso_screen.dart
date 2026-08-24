import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/cart_badge_notifier.dart';
import '../../services/carteira_badge_notifier.dart';
import '../../services/auth_storage.dart';
import '../../services/main_navigation_controller.dart';
import '../../widgets/clubbar_app_bar.dart';

class PagamentoSucessoScreen extends StatefulWidget {
  final bool sucesso;
  final double cashbackGerado;

  const PagamentoSucessoScreen({
    super.key,
    this.sucesso = true,
    this.cashbackGerado = 0,
  });

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
    final sucesso = widget.sucesso;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: ClubbarAppBar(mostrarVoltar: false),

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
                  color: Colors.black.withValues(alpha: 0.08),
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
                    color: (sucesso ? Colors.green : Colors.red).withValues(
                      alpha: 0.12,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    sucesso ? Icons.check_circle : Icons.error_outline,
                    color: sucesso ? Colors.green : Colors.red,
                    size: 64,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  sucesso
                      ? 'Pagamento realizado com sucesso'
                      : 'Pagamento cancelado pelo cliente',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                if (sucesso && widget.cashbackGerado > 0) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.amber.shade600),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.savings_rounded, color: Colors.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Você ganhou ${_moeda(widget.cashbackGerado)} de cashback para usar nas próximas compras de produtos desta loja. O saldo será liberado conforme as regras do estabelecimento.',
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                Text(
                  sucesso
                      ? 'Acompanhe sua compra através de sua carteira.'
                      : 'Não foi possível concluir o pagamento. Você pode tentar novamente pelo carrinho.',
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
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);

                      Future.delayed(const Duration(milliseconds: 100), () {
                        MainNavigationController.irParaHome();
                      });
                    },
                    icon: const Icon(Icons.home),
                    label: const Text(
                      'Ir para Home',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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

  String _moeda(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
}
