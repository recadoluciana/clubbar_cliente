import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/loja.dart';
import '../main/main_navigation_screen.dart';

class PixPagamentoScreen extends StatelessWidget {
  final Loja loja;
  final Map<String, dynamic> pagamento;

  const PixPagamentoScreen({
    super.key,
    required this.loja,
    required this.pagamento,
  });

  String get status {
    return (pagamento['status'] ?? 'PENDENTE').toString();
  }

  String get vendaId {
    return (pagamento['venda_id'] ?? '').toString();
  }

  String get codigoPix {
    return (pagamento['pix_copia_cola'] ??
            pagamento['qr_code_text'] ??
            pagamento['copia_cola'] ??
            '')
        .toString();
  }

  String get qrCodeBase64 {
    return (pagamento['qr_code_base64'] ?? '').toString();
  }

  void copiarCodigoPix(BuildContext context) {
    if (codigoPix.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código PIX não disponível')),
      );
      return;
    }

    // sem usar plugin extra por enquanto
    // vamos usar o Clipboard do Flutter
    // ignore: deprecated_member_use
    Clipboard.setData(ClipboardData(text: codigoPix));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código PIX copiado com sucesso')),
    );
  }

  void atualizarStatus(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Consulta de status será a próxima etapa')),
    );
  }

  void voltarParaHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  Widget _qrCodeWidget() {
    if (qrCodeBase64.trim().isEmpty) {
      return Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.qr_code_2_rounded,
          size: 90,
          color: Colors.black54,
        ),
      );
    }

    try {
      final bytes = base64Decode(qrCodeBase64);
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.memory(bytes, width: 220, height: 220, fit: BoxFit.cover),
      );
    } catch (_) {
      return Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          size: 70,
          color: Colors.black54,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusPago = status.toUpperCase() == 'PAGO';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(title: const Text('Pagamento PIX')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF111111),
                  Color(0xFF1E1E1E),
                  Color(0xFF2A2A2A),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.pix, size: 34, color: Colors.green),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pague com PIX',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        loja.nome,
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 14,
                        ),
                      ),
                      if (vendaId.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Venda #$vendaId',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: statusPago
                  ? Colors.green.withOpacity(0.10)
                  : Colors.amber.withOpacity(0.10),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: statusPago ? Colors.green : Colors.amber.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  statusPago ? Icons.check_circle_outline : Icons.timelapse,
                  color: statusPago ? Colors.green : Colors.amber.shade800,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Status do pagamento: $status',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: statusPago ? Colors.green : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Escaneie o QR Code',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Center(child: _qrCodeWidget()),
          const SizedBox(height: 24),
          const Text(
            'Ou copie o código PIX',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: SelectableText(
              codigoPix.trim().isEmpty
                  ? 'Código PIX não disponível'
                  : codigoPix,
              style: TextStyle(color: Colors.grey.shade800, height: 1.4),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => copiarCodigoPix(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.copy_all_rounded),
              label: const Text(
                'Copiar código PIX',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => atualizarStatus(context),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Atualizar status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: TextButton(
              onPressed: () => voltarParaHome(context),
              child: const Text(
                'Voltar para Home',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
