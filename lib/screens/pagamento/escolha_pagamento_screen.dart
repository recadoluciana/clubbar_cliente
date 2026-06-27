import 'package:flutter/material.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import 'pix_pagamento_screen.dart';
import '../../widgets/clubbar_app_bar.dart';
import 'politica_compra_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class EscolhaPagamentoScreen extends StatefulWidget {
  final Loja loja;

  final double totalProdutos;
  final double totalIngressos;

  final double? taxaConveniencia;
  final double? totalPagar;

  final VoidCallback? onVoltar;

  const EscolhaPagamentoScreen({
    super.key,
    required this.loja,
    required this.totalProdutos,
    this.totalIngressos = 0,
    this.taxaConveniencia,
    this.totalPagar,
    this.onVoltar,
  });

  @override
  State<EscolhaPagamentoScreen> createState() => _EscolhaPagamentoScreenState();
}

class _EscolhaPagamentoScreenState extends State<EscolhaPagamentoScreen> {
  final ApiService apiService = ApiService();
  final AuthStorage authStorage = AuthStorage();

  bool carregandoPix = false;

  double get percentualTaxaProduto => widget.loja.vrtaxaprod;
  double get percentualTaxaIngresso => widget.loja.vrtaxaing;

  double get taxaProdutoSplit {
    return widget.totalProdutos * (percentualTaxaProduto / 100);
  }

  double get taxaIngressoCliente {
    return widget.totalIngressos * (percentualTaxaIngresso / 100);
  }

  double get taxaClubbarTotal {
    return taxaProdutoSplit + taxaIngressoCliente;
  }

  double get totalPagar {
    return widget.totalProdutos + widget.totalIngressos + taxaIngressoCliente;
  }

  double get valorParceiro {
    return totalPagar - taxaClubbarTotal;
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

    try {
      final resposta = await apiService.pagarAsaas(
        clienteId: clienteId,
        organizacaoId: widget.loja.organizacaoId,
        lojaId: widget.loja.id,
      );

      final checkoutUrl = resposta['checkout_url'];

      if (checkoutUrl == null || checkoutUrl.toString().isEmpty) {
        throw Exception('Checkout Asaas não retornado.');
      }

      await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
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
    print(
      'ESCOLHA PAGAMENTO loja=${widget.loja.nome} taxaIng=${widget.loja.vrtaxaing} taxaProd=${widget.loja.vrtaxaprod}',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: ClubbarAppBar(mostrarVoltar: true, onVoltar: widget.onVoltar),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Text(
              widget.loja.nome,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Resumo da compra',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
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
                  taxaIngressoCliente,
                ),

                const Divider(height: 28),

                _linhaResumo('Total a pagar', totalPagar, destaque: true),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: carregandoPix ? null : pagarPix,
              icon: carregandoPix
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.pix),
              label: const Text('Continuar para pagamento'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green,
              ),
            ),
          ),

          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PoliticaCompraScreen()),
              );
            },
            icon: const Icon(Icons.policy_outlined),
            label: const Text(
              'Política de Compra - Clique aqui',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
