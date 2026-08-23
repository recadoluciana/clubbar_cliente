import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/cart_badge_notifier.dart';
import '../../services/carteira_badge_notifier.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_app_bar.dart';
import 'pagamento_sucesso_screen.dart';

class PixPagamentoScreen extends StatefulWidget {
  final Loja loja;
  final Map<String, dynamic> pagamento;
  final int? reservaIngressoId;
  final int? clienteId;

  const PixPagamentoScreen({
    super.key,
    required this.loja,
    required this.pagamento,
    this.reservaIngressoId,
    this.clienteId,
  });

  @override
  State<PixPagamentoScreen> createState() => _PixPagamentoScreenState();
}

class _PixPagamentoScreenState extends State<PixPagamentoScreen> {
  final apiService = ApiService();
  Timer? _timerStatus;
  Timer? _timerExpiracao;
  bool _consultando = false;
  bool _confirmacaoProcessada = false;
  bool _expiracaoPendente = false;
  late final DateTime _expiraEm;
  late final Duration _duracaoValidade;
  Duration _tempoRestante = Duration.zero;

  @override
  void initState() {
    super.initState();
    _expiraEm = _obterDataExpiracao();
    final duracaoInicial = _expiraEm.difference(DateTime.now());
    _duracaoValidade = duracaoInicial.isNegative
        ? Duration.zero
        : duracaoInicial;
    _atualizarTempoRestante();

    _timerStatus = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _consultarPagamento(),
    );
    _timerExpiracao = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _atualizarTempoRestante(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _consultarPagamento());
  }

  @override
  void dispose() {
    _timerStatus?.cancel();
    _timerExpiracao?.cancel();
    super.dispose();
  }

  DateTime _obterDataExpiracao() {
    final valor =
        widget.pagamento['expiration_date'] ??
        widget.pagamento['pix_expiration_date'];
    final data = DateTime.tryParse(valor?.toString() ?? '');
    if (data == null) return DateTime.now().add(const Duration(minutes: 5));
    return data.isUtc ? data.toLocal() : data;
  }

  void _atualizarTempoRestante() {
    if (_confirmacaoProcessada) return;
    final restante = _expiraEm.difference(DateTime.now());
    final atualizado = restante.isNegative ? Duration.zero : restante;
    if (mounted) setState(() => _tempoRestante = atualizado);
    if (atualizado > Duration.zero) return;

    _timerExpiracao?.cancel();
    _timerStatus?.cancel();
    _validarAntesDeExpirar();
  }

  Future<void> _validarAntesDeExpirar() async {
    if (_confirmacaoProcessada) return;
    if (_consultando) {
      _expiracaoPendente = true;
      return;
    }
    await _consultarPagamento(validacaoFinal: true);
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

  double get valorTotal {
    final valor = widget.pagamento['valor_total'] ?? widget.pagamento['valor'];
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }

  String get valorTotalFormatado =>
      'R\$ ${valorTotal.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> _consultarPagamento({bool validacaoFinal = false}) async {
    if (pagamentoId.isEmpty || _confirmacaoProcessada) {
      if (validacaoFinal) _encerrarComoExpirado();
      return;
    }
    if (_consultando) {
      if (validacaoFinal) _expiracaoPendente = true;
      return;
    }
    _consultando = true;

    try {
      final response =
          widget.reservaIngressoId != null && widget.clienteId != null
          ? await apiService.consultarReserva(
              reservaId: widget.reservaIngressoId!,
              clienteId: widget.clienteId!,
            )
          : await apiService.consultarPixPorPagamentoId(
              pagamentoId: pagamentoId,
            );

      final statusAtual =
          (response['status_pagamento'] ?? response['status'] ?? '')
              .toString()
              .toUpperCase();

      if (statusAtual == 'PAGO') {
        _confirmacaoProcessada = true;
        _timerStatus?.cancel();
        _timerExpiracao?.cancel();
        if (!mounted) return;
        CartBadgeNotifier.limpar();
        CarteiraBadgeNotifier.atualizar();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PagamentoSucessoScreen(sucesso: true),
          ),
        );
      } else if ({'EXPIRED', 'EXPIRADO'}.contains(statusAtual)) {
        _encerrarComoExpirado();
      } else if ({
        'SUBSTITUIDO',
        'CANCELADO',
        'CANCELLED',
        'CANCELED',
      }.contains(statusAtual)) {
        _confirmacaoProcessada = true;
        _timerStatus?.cancel();
        _timerExpiracao?.cancel();
        if (!mounted) return;
        AppSnackBar.erro(
          context,
          'Pagamento não concluído. O carrinho foi mantido.',
        );
        Navigator.pop(context, false);
      } else if (validacaoFinal) {
        _encerrarComoExpirado();
      }
    } catch (_) {
      if (validacaoFinal) _encerrarComoExpirado();
      // Enquanto houver tempo, a proxima consulta tenta novamente.
    } finally {
      _consultando = false;
      if (_expiracaoPendente && !_confirmacaoProcessada) {
        _expiracaoPendente = false;
        unawaited(_consultarPagamento(validacaoFinal: true));
      }
    }
  }

  void _encerrarComoExpirado() {
    if (_confirmacaoProcessada || !mounted) return;
    _confirmacaoProcessada = true;
    _timerStatus?.cancel();
    _timerExpiracao?.cancel();
    AppSnackBar.aviso(
      context,
      'O QR Code PIX expirou. O carrinho foi mantido para uma nova tentativa.',
    );
    Navigator.pop(context, false);
  }

  double get _progressoExpiracao {
    final total = _duracaoValidade.inMilliseconds;
    if (total <= 0) return 0;
    return (_tempoRestante.inMilliseconds / total).clamp(0.0, 1.0);
  }

  String get _tempoRestanteFormatado {
    final minutos = _tempoRestante.inMinutes;
    final segundos = _tempoRestante.inSeconds.remainder(60);
    return '${minutos.toString().padLeft(2, '0')}:'
        '${segundos.toString().padLeft(2, '0')}';
  }

  Widget _barraExpiracao() {
    final urgente = _tempoRestante <= const Duration(minutes: 1);
    final cor = urgente ? Colors.red : Colors.green;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 20, color: cor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'QR Code expira em $_tempoRestanteFormatado',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: urgente ? Colors.red.shade700 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progressoExpiracao,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(cor),
            ),
          ),
        ],
      ),
    );
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
            color: Colors.black.withValues(alpha: 0.08),
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
                  color: Colors.black.withValues(alpha: 0.12),
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
                      Text(
                        widget.loja.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pagamento com Pix',
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, color: Colors.green),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Valor total',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  valorTotalFormatado,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _barraExpiracao(),

          const SizedBox(height: 12),

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
