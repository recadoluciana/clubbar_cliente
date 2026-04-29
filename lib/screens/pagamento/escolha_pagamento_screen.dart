import 'package:flutter/material.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import 'cartao_pagamento_screen.dart';
import 'pagamento_sucesso_screen.dart';

class EscolhaPagamentoScreen extends StatefulWidget {
  final Loja loja;
  final double totalProdutos;
  final double taxaConveniencia;
  final double totalPagar;

  const EscolhaPagamentoScreen({
    super.key,
    required this.loja,
    required this.totalProdutos,
    required this.taxaConveniencia,
    required this.totalPagar,
  });

  @override
  State<EscolhaPagamentoScreen> createState() => _EscolhaPagamentoScreenState();
}

class _EscolhaPagamentoScreenState extends State<EscolhaPagamentoScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();

  bool carregandoPix = false;

  Future<void> pagarPix() async {
    setState(() => carregandoPix = true);

    try {
      final clienteId = await authStorage.obterClienteId();

      if (clienteId == null || clienteId == 0) {
        throw Exception('Cliente não identificado');
      }

      await apiService.pagarCarrinhoPix(
        clienteId: clienteId,
        organizacaoId: widget.loja.organizacaoId,
        lojaId: widget.loja.id,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PagamentoSucessoScreen()),
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

  void abrirCartao(String tipoPagamento) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartaoPagamentoScreen(
          loja: widget.loja,
          tipoPagamento: tipoPagamento,
          totalProdutos: widget.totalProdutos,
          taxaConveniencia: widget.taxaConveniencia,
          totalPagar: widget.totalPagar,
        ),
      ),
    );
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
          'R\$ ${valor.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: destaque ? 18 : 15,
            fontWeight: destaque ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(title: const Text('Escolha o pagamento')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                _linhaResumo('Total produtos', widget.totalProdutos),
                const SizedBox(height: 8),
                _linhaResumo('Taxa de conveniência', widget.taxaConveniencia),
                const Divider(height: 24),
                _linhaResumo(
                  'Total a pagar',
                  widget.totalPagar,
                  destaque: true,
                ),
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
