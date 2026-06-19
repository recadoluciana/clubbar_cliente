import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../widgets/clubbar_app_bar.dart';
import 'pagamento_sucesso_screen.dart';

class PixPagamentoScreen extends StatefulWidget {
  final Loja loja;
  final Map<String, dynamic> pagamento;

  const PixPagamentoScreen({
    super.key,
    required this.loja,
    required this.pagamento,
  });

  @override
  State<PixPagamentoScreen> createState() => _PixPagamentoScreenState();
}

class _PixPagamentoScreenState extends State<PixPagamentoScreen> {
  final apiService = ApiService();
  Timer? _timer;

  @override
  void initState() {
    super.initState();

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

  String get status {
    return (widget.pagamento['status'] ?? 'PENDENTE').toString();
  }

  String get vendaId {
    return (widget.pagamento['venda_id'] ?? '').toString();
  }

  String get pagamentoId {
    return (widget.pagamento['pagamento_id'] ?? '').toString();
  }

  String get codigoPix {
    return (widget.pagamento['pix_copia_cola'] ??
            widget.pagamento['qr_code_text'] ??
            widget.pagamento['copia_cola'] ??
            '')
        .toString();
  }

  Future<void> _consultarPagamento() async {
    if (pagamentoId.isEmpty) return;

    try {
      final response = await apiService.consultarPixPorPagamentoId(
        pagamentoId: pagamentoId,
      );

      final statusAtual = (response['status'] ?? '').toString().toUpperCase();

      if (statusAtual == 'PAGO') {
        _timer?.cancel();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PagamentoSucessoScreen(sucesso: true),
          ),
        );
      }
    } catch (_) {}
  }

  void copiarCodigoPix(BuildContext context) {
    if (codigoPix.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código PIX não disponível')),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: codigoPix));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código PIX copiado com sucesso')),
    );
  }

  Widget _qrCodeWidget() {
    if (codigoPix.trim().isEmpty) {
      return Container(
        width: 185,
        height: 185,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.qr_code_2_rounded,
          size: 72,
          color: Colors.black54,
        ),
      );
    }

    return Container(
      width: 200,
      height: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: QrImageView(
        data: codigoPix,
        version: QrVersions.auto,
        size: 180,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusPago = status.toUpperCase() == 'PAGO';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: ClubbarAppBar(
        mostrarVoltar: true,
        onVoltar: () {
          Navigator.pop(context);
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
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
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.pix, size: 28, color: Colors.green),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pague com PIX',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.loja.nome,
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 13,
                        ),
                      ),
                      if (vendaId.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Venda #$vendaId',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: statusPago
                  ? Colors.green.withOpacity(0.10)
                  : Colors.amber.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: statusPago ? Colors.green : Colors.amber.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  statusPago ? Icons.check_circle_outline : Icons.timelapse,
                  size: 21,
                  color: statusPago ? Colors.green : Colors.amber.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusPago
                        ? 'Pagamento confirmado'
                        : 'Aguardando pagamento PIX...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: statusPago ? Colors.green : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Escaneie o QR Code',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Center(child: _qrCodeWidget()),

          const SizedBox(height: 16),

          const Text(
            'Ou copie o código PIX',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: SelectableText(
              codigoPix.trim().isEmpty
                  ? 'Código PIX não disponível'
                  : codigoPix,
              style: TextStyle(
                color: Colors.grey.shade800,
                height: 1.3,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => copiarCodigoPix(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.copy_all_rounded, size: 20),
              label: const Text(
                'Copiar código PIX',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
