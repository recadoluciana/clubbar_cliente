import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/cart_badge_notifier.dart';
import '../../services/carteira_badge_notifier.dart';
import '../../widgets/clubbar_app_bar.dart';
import 'pagamento_sucesso_screen.dart';

/// Aguarda, no Clubbar, a confirmação de um PIX gerado pelo Checkout Pro.
///
/// O Checkout Pro é hospedado pelo Mercado Pago e, para PIX, não redireciona
/// automaticamente para a loja. Esta tela consulta a transação em segundo
/// plano para que o cliente não precise tocar em "Voltar para Clubbar".
class AguardandoPagamentoMercadoPagoScreen extends StatefulWidget {
  final Loja loja;
  final String preferenceId;

  const AguardandoPagamentoMercadoPagoScreen({
    super.key,
    required this.loja,
    required this.preferenceId,
  });

  @override
  State<AguardandoPagamentoMercadoPagoScreen> createState() =>
      _AguardandoPagamentoMercadoPagoScreenState();
}

class _AguardandoPagamentoMercadoPagoScreenState
    extends State<AguardandoPagamentoMercadoPagoScreen> {
  final ApiService _apiService = ApiService();
  Timer? _timer;
  bool _consultando = false;
  bool _confirmado = false;
  String? _mensagem;

  @override
  void initState() {
    super.initState();
    _consultarPagamento();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _consultarPagamento(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _consultarPagamento() async {
    if (_consultando || _confirmado) return;
    _consultando = true;
    try {
      final resposta = await _apiService.consultarCheckoutMercadoPago(
        preferenceId: widget.preferenceId,
      );
      final status = (resposta['status'] ?? '').toString().toUpperCase();
      if (status != 'PAGO') return;

      _confirmado = true;
      _timer?.cancel();

      final clienteId = await AuthStorage().obterClienteId();
      if (clienteId != null && clienteId > 0) {
        final totalCarrinho = await _apiService.buscarQuantidadeCarrinho(
          clienteId: clienteId,
        );
        CartBadgeNotifier.atualizar(totalCarrinho);
        CarteiraBadgeNotifier.atualizar();
      }

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PagamentoSucessoScreen(
            tituloSucesso: 'Pagamento realizado com sucesso',
            descricaoSucesso:
                'Seu produto já está disponível na Carteira.\nO QR Code também será enviado por e-mail.',
            lojaDestino: widget.loja,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _mensagem =
              'Ainda não foi possível confirmar o pagamento. Vamos tentar novamente.';
        });
      }
    } finally {
      _consultando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(
        titulo: 'Pagamento',
        mostrarSessao: false,
        mostrarVoltar: false,
      ),
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
                    color: Colors.blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pix_rounded,
                    color: Colors.blue,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Aguardando confirmação do PIX',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  _mensagem ??
                      'Conclua o pagamento na aba do Mercado Pago. Assim que o PIX for identificado, esta tela será atualizada automaticamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                const CircularProgressIndicator(color: Colors.blue),
                const SizedBox(height: 22),
                TextButton.icon(
                  onPressed: _consultarPagamento,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Verificar agora'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
