import 'package:flutter/material.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import 'checkout_cartao_screen.dart';
import 'pix_pagamento_screen.dart';
import '../../widgets/clubbar_app_bar.dart';

import '../../services/main_navigation_controller.dart';

class EscolhaPagamentoScreen extends StatefulWidget {
  final Loja loja;

  final double totalProdutos;
  final double totalIngressos;

  final double? taxaConveniencia;
  final double? totalPagar;

  const EscolhaPagamentoScreen({
    super.key,
    required this.loja,
    required this.totalProdutos,
    this.totalIngressos = 0,
    this.taxaConveniencia,
    this.totalPagar,
  });

  @override
  State<EscolhaPagamentoScreen> createState() => _EscolhaPagamentoScreenState();
}

class _EscolhaPagamentoScreenState extends State<EscolhaPagamentoScreen> {
  final ApiService apiService = ApiService();
  final AuthStorage authStorage = AuthStorage();

  bool carregandoPix = false;

  double get percentualTaxaIngresso => widget.loja.vrtaxaing;

  double get taxaIngressos {
    return widget.totalIngressos * (percentualTaxaIngresso / 100);
  }

  double get taxaConveniencia {
    return taxaIngressos;
  }

  double get totalPagar {
    return widget.totalProdutos + widget.totalIngressos + taxaConveniencia;
  }

  String _moeda(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> pagarPix() async {
    setState(() => carregandoPix = true);

    try {
      final clienteId = await authStorage.obterClienteId();

      if (clienteId == null || clienteId == 0) {
        throw Exception('Cliente não identificado');
      }

      final resposta = await apiService.pagarCarrinhoPix(
        clienteId: clienteId,
        organizacaoId: widget.loja.organizacaoId,
        lojaId: widget.loja.id,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PixPagamentoScreen(loja: widget.loja, pagamento: resposta),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => carregandoPix = false);
      }
    }
  }

  Future<void> abrirCartao(String tipoPagamento) async {
    final clienteId = await authStorage.obterClienteId();

    if (clienteId == null || clienteId == 0) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cliente não identificado')));
      return;
    }

    final uri =
        Uri.parse(
          'https://bitbeer-production.up.railway.app/static/checkout_cartao.html',
        ).replace(
          queryParameters: {
            'cliente_id': clienteId.toString(),
            'organizacao_id': widget.loja.organizacaoId.toString(),
            'loja_id': widget.loja.id.toString(),
            'tipo_pagamento': tipoPagamento,
            'amount': totalPagar.toStringAsFixed(2),
          },
        );

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutCartaoScreen(url: uri.toString()),
      ),
    );

    if (resultado == true && mounted) {
      MainNavigationController.irParaHome();
    }
  }

  Widget _linhaResumo(String titulo, double valor, {bool destaque = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: destaque ? 18 : 15,
              fontWeight: destaque ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
        Text(
          _moeda(valor),
          style: TextStyle(
            fontSize: destaque ? 18 : 15,
            fontWeight: destaque ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _linhaResumoComIcone({
    required IconData icon,
    required String titulo,
    required double valor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.black87),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          _moeda(valor),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: const ClubbarAppBar(mostrarVoltar: true),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Pagamento - ${widget.loja.nome}',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _linhaResumoComIcone(
                  icon: Icons.shopping_bag_outlined,
                  titulo: 'Produtos',
                  valor: widget.totalProdutos,
                ),

                const SizedBox(height: 16),

                _linhaResumoComIcone(
                  icon: Icons.confirmation_number_outlined,
                  titulo: 'Ingressos',
                  valor: widget.totalIngressos,
                ),

                const SizedBox(height: 10),

                _linhaResumo(
                  'Taxa de conveniência ingressos (${percentualTaxaIngresso.toStringAsFixed(0)}%)',
                  taxaConveniencia,
                ),

                const Divider(height: 28),

                _linhaResumo('Total a pagar', totalPagar, destaque: true),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: carregandoPix ? null : pagarPix,
              icon: carregandoPix
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.pix),
              label: const Text('Pagar com PIX'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => abrirCartao('CREDIT_CARD'),
              icon: const Icon(Icons.credit_card),
              label: const Text('Cartão de crédito'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () => abrirCartao('DEBIT_CARD'),
              icon: const Icon(Icons.credit_card),
              label: const Text('Cartão de débito'),
            ),
          ),
        ],
      ),
    );
  }
}
