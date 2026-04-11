import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/carrinho_item.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../pagamento/cartao_pagamento_screen.dart';

enum FormaPagamento { pix, credito, debito }

class CarrinhoScreen extends StatefulWidget {
  final Loja loja;

  const CarrinhoScreen({super.key, required this.loja});

  @override
  State<CarrinhoScreen> createState() => _CarrinhoScreenState();
}

class _CarrinhoScreenState extends State<CarrinhoScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();

  FormaPagamento formaPagamento = FormaPagamento.pix;

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

  double get total {
    return itensCarrinho.fold<double>(0, (soma, item) => soma + item.subtotal);
  }

  Future<void> finalizarPagamento() async {
    if (clienteId == null || clienteId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para continuar')),
      );
      return;
    }

    if (formaPagamento == FormaPagamento.pix) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tela PIX ainda está em ajuste.')),
      );
      return;
    }

    if (formaPagamento == FormaPagamento.credito ||
        formaPagamento == FormaPagamento.debito) {
      final tipo = formaPagamento == FormaPagamento.debito
          ? 'DEBIT_CARD'
          : 'CREDIT_CARD';

      final sucesso = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CartaoPagamentoScreen(
            loja: widget.loja,
            tipoPagamento: tipo,
            totalProdutos: total,
            taxaConveniencia: 0,
            totalPagar: total,
          ),
        ),
      );

      if (sucesso == true) {
        await carregarCarrinho();

        if (!mounted) return;

        if (itensCarrinho.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pagamento concluído com sucesso')),
          );
        }
      }

      return;
    }

    final url = apiService.montarUrlCartaoWeb(
      clienteId: clienteId!,
      organizacaoId: widget.loja.organizacaoId,
      lojaId: widget.loja.id,
    );

    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir a página de pagamento'),
        ),
      );
    }
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

  Widget _cardPagamento({
    required FormaPagamento valor,
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required Color cor,
  }) {
    final selecionado = formaPagamento == valor;

    return InkWell(
      onTap: () {
        setState(() {
          formaPagamento = valor;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selecionado ? cor.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selecionado ? cor : Colors.grey.shade300,
            width: selecionado ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: cor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icone, color: cor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(
              selecionado ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selecionado ? cor : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemCarrinho(ItemCarrinho item) {
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

              /// TEXTO PRINCIPAL
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nome,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    /// OBSERVAÇÃO
                    if (item.observacao.isNotEmpty)
                      Text(
                        item.observacao,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),

                    const SizedBox(height: 8),

                    /// QUANTIDADE
                    Text(
                      'Qtd: ${item.quantidade}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// BOTÃO REMOVER
                    TextButton(
                      onPressed: () => removerItem(item),
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

              /// PREÇO / SUBTOTAL
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R\$ ${item.preco.toStringAsFixed(2)}',
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
                    'R\$ ${item.subtotal.toStringAsFixed(2)}',
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

  Future<void> removerItem(ItemCarrinho item) async {
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
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('1 unidade de "${item.nome}" removida do carrinho'),
        ),
      );

      await carregarCarrinho();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vazio = itensCarrinho.isEmpty;

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
                  else
                    ...itensCarrinho.map(_itemCarrinho),
                  const SizedBox(height: 14),
                  if (!vazio) ...[
                    const Text(
                      'Forma de pagamento',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _cardPagamento(
                      valor: FormaPagamento.pix,
                      titulo: 'PIX',
                      subtitulo: '',
                      icone: Icons.pix,
                      cor: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _cardPagamento(
                      valor: FormaPagamento.credito,
                      titulo: 'Cartão de Crédito',
                      subtitulo: '',
                      icone: Icons.credit_card,
                      cor: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _cardPagamento(
                      valor: FormaPagamento.debito,
                      titulo: 'Cartão de Débito',
                      subtitulo: '',
                      icone: Icons.payment,
                      cor: Colors.deepPurple,
                    ),
                    const SizedBox(height: 24),
                    Container(
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
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            'R\$ ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: finalizarPagamento,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.lock_outline),
                        label: const Text(
                          'Efetuar pagamento',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
