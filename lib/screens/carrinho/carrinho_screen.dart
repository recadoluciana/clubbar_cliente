import 'package:flutter/material.dart';

import '../../models/carrinho_item.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/cart_badge_notifier.dart';
import '../../utils/value_formatters.dart';
import '../pagamento/escolha_pagamento_screen.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../produtos_loja/produtos_loja_screen.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_page_header.dart';

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
  final String nmparticipante;
  final String cpfparticipante;
  final String idtipoproduto;

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
    required this.nmparticipante,
    required this.cpfparticipante,
    required this.idtipoproduto,
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
  bool alterandoQuantidade = false;
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
      final nome = item.nmparticipante.trim();
      final cpf = item.cpfparticipante.trim();

      final chave =
          '${item.produtoId}__${obs.toLowerCase()}__'
          '${nome.toLowerCase()}__${cpf.toLowerCase()}';

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
          nmparticipante: atual.nmparticipante,
          cpfparticipante: atual.cpfparticipante,
          idtipoproduto: atual.idtipoproduto,
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
          nmparticipante: item.nmparticipante,
          cpfparticipante: item.cpfparticipante,
          idtipoproduto: item.idtipoproduto.trim().toUpperCase(),
        );
      }
    }

    return mapa.values.toList();
  }

  double get total {
    return itensAgrupados.fold<double>(0, (soma, item) => soma + item.subtotal);
  }

  double get totalProdutos {
    double total = 0;

    for (final item in itensCarrinho) {
      if (item.idtipoproduto == 'P') {
        total += item.precoFinal * item.quantidade;
      }
    }

    return total;
  }

  double get totalIngressos {
    double total = 0;

    for (final item in itensCarrinho) {
      if (item.idtipoproduto == 'I') {
        total += item.precoFinal * item.quantidade;
      }
    }

    return total;
  }

  Future<void> _atualizarCarrinhoEBadge() async {
    await carregarCarrinho();

    if (clienteId == null || clienteId == 0) return;

    final quantidade = await apiService.buscarQuantidadeCarrinho(
      clienteId: clienteId!,
    );

    CartBadgeNotifier.atualizar(quantidade);
  }

  Future<void> aumentarQuantidade(ItemCarrinhoAgrupado item) async {
    if (alterandoQuantidade) return;

    if (item.idtipoproduto == 'I') {
      AppSnackBar.aviso(
        context,
        'Para adicionar outro ingresso, informe os dados do novo participante.',
      );
      return;
    }

    if (clienteId == null || clienteId == 0) {
      AppSnackBar.erro(context, 'Cliente não identificado.');
      return;
    }

    setState(() {
      alterandoQuantidade = true;
    });

    try {
      await apiService.adicionarAoCarrinho(
        clienteId: clienteId!,
        organizacaoId: widget.loja.organizacaoId,
        lojaId: widget.loja.id,
        produtoId: item.produtoId,
        quantidade: 1,
        observacao: item.observacao,
      );

      await _atualizarCarrinhoEBadge();

      if (!mounted) return;

      AppSnackBar.sucesso(context, 'Quantidade de "${item.nome}" aumentada.');
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, apiService.mensagemErroAmigavel(e));
    } finally {
      if (mounted) {
        setState(() {
          alterandoQuantidade = false;
        });
      }
    }
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
      if (!mounted) return;

      setState(() {
        erro = apiService.mensagemErroAmigavel(e);
        itensCarrinho = [];
        carregando = false;
      });
    }
  }

  Future<void> diminuirQuantidade(ItemCarrinhoAgrupado item) async {
    if (alterandoQuantidade) return;

    if (carrinhoId == null || carrinhoId == 0) {
      AppSnackBar.erro(context, 'Carrinho inválido para remoção.');
      return;
    }

    setState(() {
      alterandoQuantidade = true;
    });

    try {
      await apiService.removerItemCarrinho(
        carrinhoId: carrinhoId!,
        produtoId: item.produtoId,
        observacao: item.observacao,
      );

      await _atualizarCarrinhoEBadge();

      if (!mounted) return;

      AppSnackBar.sucesso(
        context,
        item.quantidade > 1
            ? 'Quantidade de "${item.nome}" diminuída.'
            : '"${item.nome}" removido do carrinho.',
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, apiService.mensagemErroAmigavel(e));
    } finally {
      if (mounted) {
        setState(() {
          alterandoQuantidade = false;
        });
      }
    }
  }

  Future<void> removerItemCompleto(ItemCarrinhoAgrupado item) async {
    if (alterandoQuantidade) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF6F6F6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Remover item',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Deseja remover todas as unidades de "${item.nome}" do carrinho?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remover'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;
    if (!mounted) return;

    if (carrinhoId == null || carrinhoId == 0) {
      AppSnackBar.erro(context, 'Carrinho inválido para remoção.');
      return;
    }

    setState(() {
      alterandoQuantidade = true;
    });

    try {
      for (var i = 0; i < item.quantidade; i++) {
        await apiService.removerItemCarrinho(
          carrinhoId: carrinhoId!,
          produtoId: item.produtoId,
          observacao: item.observacao,
        );
      }

      await _atualizarCarrinhoEBadge();

      if (!mounted) return;

      AppSnackBar.sucesso(context, '"${item.nome}" removido do carrinho.');
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, apiService.mensagemErroAmigavel(e));
    } finally {
      if (mounted) {
        setState(() {
          alterandoQuantidade = false;
        });
      }
    }
  }

  Widget _controleQuantidade(ItemCarrinhoAgrupado item) {
    final permiteAumentar = item.idtipoproduto != 'I';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Diminuir quantidade',
                onPressed: alterandoQuantidade
                    ? null
                    : () => diminuirQuantidade(item),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_rounded, size: 19),
              ),
              Text(
                '${item.quantidade}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                tooltip: permiteAumentar
                    ? 'Aumentar quantidade'
                    : 'Adicione outro ingresso pela agenda',
                onPressed: alterandoQuantidade || !permiteAumentar
                    ? null
                    : () => aumentarQuantidade(item),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_rounded, size: 19),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Remover item',
          onPressed: alterandoQuantidade
              ? null
              : () => removerItemCompleto(item),
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.red,
            size: 22,
          ),
        ),
      ],
    );
  }

  Future<void> abrirEscolhaPagamento() async {
    if (itensCarrinho.isEmpty) {
      AppSnackBar.aviso(context, 'Seu carrinho está vazio.');
      return;
    }

    if (itensCarrinho.any(
      (item) => item.idtipoproduto.trim().toUpperCase() == 'I',
    )) {
      AppSnackBar.erro(
        context,
        'Ingressos não podem ser pagos pelo carrinho de produtos.',
      );
      return;
    }

    double totalProdutos = 0;

    for (final item in itensCarrinho) {
      totalProdutos += item.precoFinal * item.quantidade;
    }

    try {
      final lojaAtualizada = await apiService.buscarDadosLoja(widget.loja.id);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EscolhaPagamentoScreen(
            loja: lojaAtualizada,
            totalProdutos: totalProdutos,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(
        context,
        'Erro ao buscar dados da loja: ${apiService.mensagemErroAmigavel(e)}',
      );
    }
  }

  Widget _botaoContinuarComprando() {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProdutosLojaScreen(loja: widget.loja),
            ),
          );
        },
        icon: const Icon(Icons.storefront_outlined),
        label: const Text(
          'Continuar comprando',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _imagemProduto(String url, {bool ingresso = false}) {
    if (url.isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          ingresso
              ? Icons.confirmation_number_rounded
              : Icons.shopping_bag_outlined,
          color: ingresso ? Colors.deepPurple : Colors.amber.shade800,
        ),
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
    final bool ehIngresso = item.idtipoproduto == 'I';

    final String seloDesconto = item.tipodesconto.toUpperCase() == 'PERCENTUAL'
        ? '${item.vrdesconto.toStringAsFixed(0)}% OFF'
        : 'R\$ ${item.vrdesconto.toStringAsFixed(2)} OFF';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: ehIngresso ? const Color(0xFFF7F3FF) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: ehIngresso
              ? BorderSide(color: Colors.deepPurple.shade200, width: 1.5)
              : BorderSide.none,
        ),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _imagemProduto(item.fotoUrl, ingresso: ehIngresso),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ehIngresso)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.confirmation_number_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'INGRESSO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                    if (item.nmparticipante.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ehIngresso
                              ? Colors.deepPurple.withValues(alpha: 0.08)
                              : Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: ehIngresso
                              ? Border.all(color: Colors.deepPurple.shade100)
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Participante: ${item.nmparticipante}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (item.cpfparticipante.isNotEmpty)
                              Text(
                                'CPF: ${item.cpfparticipante}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _controleQuantidade(item),
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
      height: 42,
      child: ElevatedButton(
        onPressed: () => abrirEscolhaPagamento(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          'Continuar para pagamento',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vazio = itensAgrupados.isEmpty;

    final totalItens = itensAgrupados.fold<int>(
      0,
      (soma, item) => soma + item.quantidade,
    );

    final subtitulo = totalItens == 1
        ? '1 item no carrinho.'
        : '$totalItens itens no carrinho.';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: const ClubbarAppBar(mostrarVoltar: true),

      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro != null
          ? _erroWidget()
          : Column(
              children: [
                ClubbarPageHeader(
                  titulo: widget.loja.nome,
                  subtitulo: subtitulo,
                  corTitulo: Colors.blue,
                  icone: Icons.storefront_rounded,
                  imagemAvatarUrl: widget.loja.imagemUrl,
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProdutosLojaScreen(loja: widget.loja),
                          ),
                        );
                      },
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: const Text(
                        'Continuar comprando',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.amber.shade600,
                        side: BorderSide(color: Colors.amber.shade800),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: carregarCarrinho,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                      children: [
                        if (vazio)
                          _estadoVazio()
                        else ...[
                          ...itensAgrupados.map(_itemCarrinho),
                          const SizedBox(height: 6),
                          _resumoTotal(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),

      bottomNavigationBar: carregando || erro != null || vazio
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: _botaoPagar(),
              ),
            ),
    );
  }
}
