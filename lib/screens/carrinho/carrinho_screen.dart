import 'package:flutter/material.dart';

import '../../models/carrinho_item.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/cart_badge_notifier.dart';
import '../../utils/value_formatters.dart';
import '../pagamento/escolha_pagamento_screen.dart';

class ItemCarrinhoAgrupado {
  final int produtoId;
  final String nome;
  final String observacao;
  final String fotoUrl;

  final double precoOriginal;
  final double precoFinal;
  final bool descontoAtivo;
  final String tipodesconto;
  final double vrdesconto;

  final int quantidade;

  ItemCarrinhoAgrupado({
    required this.produtoId,
    required this.nome,
    required this.observacao,
    required this.fotoUrl,
    required this.precoOriginal,
    required this.precoFinal,
    required this.descontoAtivo,
    required this.tipodesconto,
    required this.vrdesconto,
    required this.quantidade,
  });

  double get subtotal => precoFinal * quantidade;
}

class CarrinhoScreen extends StatefulWidget {
  final Loja loja;

  const CarrinhoScreen({super.key, required this.loja});

  @override
  State<CarrinhoScreen> createState() => _CarrinhoScreenState();
}

class _CarrinhoScreenState extends State<CarrinhoScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();

  bool carregando = true;
  String? erro;
  int? clienteId;
  int? carrinhoId;

  List<ItemCarrinho> itensCarrinho = [];

  @override
  void initState() {
    super.initState();
    carregarCarrinho();
  }

  List<ItemCarrinhoAgrupado> get itensAgrupados {
    final Map<String, ItemCarrinhoAgrupado> mapa = {};

    for (final item in itensCarrinho) {
      final obs = item.observacao.trim();
      final chave = '${item.produtoId}__${obs.toLowerCase()}';

      if (mapa.containsKey(chave)) {
        final atual = mapa[chave]!;
        mapa[chave] = ItemCarrinhoAgrupado(
          produtoId: atual.produtoId,
          nome: atual.nome,
          observacao: atual.observacao,
          fotoUrl: atual.fotoUrl,
          precoOriginal: atual.precoOriginal,
          precoFinal: atual.precoFinal,
          descontoAtivo: atual.descontoAtivo,
          tipodesconto: atual.tipodesconto,
          vrdesconto: atual.vrdesconto,
          quantidade: atual.quantidade + item.quantidade,
        );
      } else {
        mapa[chave] = ItemCarrinhoAgrupado(
          produtoId: item.produtoId,
          nome: item.nome,
          observacao: obs,
          fotoUrl: item.fotoUrl,
          precoOriginal: item.precoOriginal,
          precoFinal: item.precoFinal,
          descontoAtivo: item.descontoAtivo,
          tipodesconto: item.tipodesconto,
          vrdesconto: item.vrdesconto,
          quantidade: item.quantidade,
        );
      }
    }

    return mapa.values.toList();
  }

  double get total {
    return itensAgrupados.fold<double>(0, (soma, item) => soma + item.subtotal);
  }

  Future<void> carregarCarrinho() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      clienteId = await authStorage.obterClienteId();

      if (clienteId == null || clienteId == 0) {
        throw Exception('Cliente não identificado. Faça login novamente.');
      }

      final data = await apiService.buscarCarrinho(
        clienteId: clienteId!,
        organizacaoId: widget.loja.organizacaoId,
        lojaId: widget.loja.id,
      );

      carrinhoId = data['carrinho_id'] as int? ?? 0;

      final lista = (data['itens'] as List? ?? [])
          .map((e) => ItemCarrinho.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        itensCarrinho = lista;
        carregando = false;
      });
    } catch (e) {
      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '');
        itensCarrinho = [];
        carregando = false;
      });
    }
  }

  Future<void> removerItemAgrupado(ItemCarrinhoAgrupado item) async {
    if (carrinhoId == null || carrinhoId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carrinho inválido para remoção')),
      );
      return;
    }

    try {
      await apiService.removerItemCarrinho(
        carrinhoId: carrinhoId!,
        produtoId: item.produtoId,
        observacao: item.observacao,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('1 unidade de "${item.nome}" removida do carrinho'),
        ),
      );

      await carregarCarrinho();

      if (clienteId != null && clienteId != 0) {
        final total = await apiService.buscarQuantidadeCarrinho(
          clienteId: clienteId!,
        );
        CartBadgeNotifier.atualizar(total);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void abrirEscolhaPagamento() {
    if (itensAgrupados.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seu carrinho está vazio')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EscolhaPagamentoScreen(
          loja: widget.loja,
          totalProdutos: total,
          taxaConveniencia: 0,
          totalPagar: total,
        ),
      ),
    );
  }

  Widget _imagemProduto(String url) {
    if (url.isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.shopping_bag_outlined, color: Colors.amber.shade800),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.image_not_supported, color: Colors.amber.shade800),
        ),
      ),
    );
  }

  Widget _itemCarrinho(ItemCarrinhoAgrupado item) {
    final bool temDesconto = item.descontoAtivo;

    final String seloDesconto = item.tipodesconto.toUpperCase() == 'PERCENTUAL'
        ? '${item.vrdesconto.toStringAsFixed(0)}% OFF'
        : 'R\$ ${item.vrdesconto.toStringAsFixed(2)} OFF';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _imagemProduto(item.fotoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (temDesconto)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          seloDesconto,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Text(
                      item.nome,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (item.observacao.isNotEmpty)
                      Text(
                        item.observacao,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Qtd: ${item.quantidade}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => removerItemAgrupado(item),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Remover',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (temDesconto) ...[
                    Text(
                      ValueFormatters.moeda(item.precoOriginal),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ValueFormatters.moeda(item.precoFinal),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.green,
                      ),
                    ),
                  ] else
                    Text(
                      ValueFormatters.moeda(item.precoFinal),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Subtotal',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  Text(
                    ValueFormatters.moeda(item.subtotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estadoVazio() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          const Text(
            'Seu carrinho está vazio',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Adicione produtos para continuar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _erroWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 56),
            const SizedBox(height: 14),
            Text(
              erro ?? 'Erro ao carregar carrinho',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: carregarCarrinho,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumoTotal() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Total',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            ValueFormatters.moeda(total),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _botaoPagar() {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: abrirEscolhaPagamento,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(Icons.lock_outline),
        label: const Text(
          'Pagar',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vazio = itensAgrupados.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(title: Text('Carrinho - ${widget.loja.nome}')),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro != null
          ? _erroWidget()
          : RefreshIndicator(
              onRefresh: carregarCarrinho,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Itens',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  if (vazio)
                    _estadoVazio()
                  else ...[
                    ...itensAgrupados.map(_itemCarrinho),
                    const SizedBox(height: 14),
                    _resumoTotal(),
                    const SizedBox(height: 18),
                    _botaoPagar(),
                  ],
                ],
              ),
            ),
    );
  }
}
