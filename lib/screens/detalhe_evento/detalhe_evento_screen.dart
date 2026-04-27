import 'package:flutter/material.dart';

import '../../models/evento_detalhe.dart';
import '../../models/evento_lote.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../utils/date_formatters.dart';
import '../pagamento/cartao_pagamento_screen.dart';

class DetalheEventoScreen extends StatefulWidget {
  final int eventoId;
  final Loja loja;

  const DetalheEventoScreen({
    super.key,
    required this.eventoId,
    required this.loja,
  });

  @override
  State<DetalheEventoScreen> createState() => _DetalheEventoScreenState();
}

class _DetalheEventoScreenState extends State<DetalheEventoScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();

  bool carregando = true;
  bool processandoCompra = false;
  String? erro;

  EventoDetalhe? evento;
  List<EventoLote> lotes = [];

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final resultados = await Future.wait([
        apiService.buscarDetalheEvento(widget.eventoId),
        apiService.buscarLotesDoEvento(widget.eventoId),
      ]);

      final detalhe = resultados[0] as EventoDetalhe;
      final listaLotes = resultados[1] as List<EventoLote>;

      setState(() {
        evento = detalhe;
        lotes = listaLotes;
        carregando = false;
      });
    } catch (e) {
      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '');
        carregando = false;
      });
    }
  }

  String formatarDataHora(String valor) {
    return DateFormatters.dataCompleta(valor);
  }

  String formatarPeriodoVenda(String inicio, String fim) {
    return DateFormatters.periodo(inicio, fim);
  }

  Future<int> _obterClienteIdLogado() async {
    final clienteId = await authStorage.obterClienteId();

    if (clienteId == null || clienteId == 0) {
      throw Exception('Faça login para continuar');
    }

    return clienteId;
  }

  Future<void> adicionarAoCarrinho(EventoLote lote) async {
    try {
      final clienteId = await _obterClienteIdLogado();

      await apiService.adicionarAoCarrinho(
        clienteId: clienteId,
        organizacaoId: widget.loja.organizacaoId,
        lojaId: widget.loja.id,
        produtoId: null,
        loteId: lote.loteId,
        idtipoproduto: 'I',
        quantidade: 1,
        observacao: 'Ingresso ${lote.nome}',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresso adicionado ao carrinho')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> comprarAgora(EventoLote lote) async {
    if (processandoCompra) return;

    setState(() {
      processandoCompra = true;
    });

    try {
      final clienteId = await _obterClienteIdLogado();

      await apiService.adicionarAoCarrinho(
        clienteId: clienteId,
        organizacaoId: widget.loja.organizacaoId,
        lojaId: widget.loja.id,
        produtoId: null,
        loteId: lote.loteId,
        idtipoproduto: 'I',
        quantidade: 1,
        observacao: 'Ingresso ${lote.nome}',
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CartaoPagamentoScreen(
            loja: widget.loja,
            tipoPagamento: 'CREDIT_CARD',
            totalProdutos: lote.preco,
            taxaConveniencia: 0,
            totalPagar: lote.preco,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          processandoCompra = false;
        });
      }
    }
  }

  Widget miniGraficoLote({required int total, required int vendidos}) {
    final vendidosAjustado = vendidos.clamp(0, total);
    final disponiveis = (total - vendidosAjustado).clamp(0, total);
    final percentualVendido = total <= 0 ? 0.0 : vendidosAjustado / total;

    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: percentualVendido,
            strokeWidth: 7,
            backgroundColor: Colors.green.withOpacity(0.18),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
          ),
          Text(
            '$disponiveis',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget linhaInfo({
    required IconData icone,
    required String titulo,
    required String valor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: Colors.black87),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$titulo: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: valor.trim().isEmpty ? 'Não informado' : valor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget cardLote(EventoLote lote) {
    final disponivel = lote.qtDisponivel < 0 ? 0 : lote.qtDisponivel;
    final esgotado = disponivel <= 0;

    final corBadge = esgotado ? Colors.red : Colors.green;
    final textoBadge = esgotado ? 'Esgotado' : 'Disponível';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  miniGraficoLote(
                    total: lote.qtTotal,
                    vendidos: lote.qtVendida,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      lote.nome,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: corBadge.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      textoBadge,
                      style: TextStyle(
                        color: corBadge,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'R\$ ${lote.preco.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              linhaInfo(
                icone: Icons.confirmation_number_outlined,
                titulo: 'Quantidade total',
                valor: '${lote.qtTotal}',
              ),
              linhaInfo(
                icone: Icons.shopping_bag_outlined,
                titulo: 'Vendidos',
                valor: '${lote.qtVendida}',
              ),
              linhaInfo(
                icone: Icons.inventory_2_outlined,
                titulo: 'Disponíveis',
                valor: '$disponivel',
              ),
              linhaInfo(
                icone: Icons.date_range_outlined,
                titulo: 'Vendas',
                valor: formatarPeriodoVenda(
                  lote.dataInicioVenda,
                  lote.dataFimVenda,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: esgotado || processandoCompra
                          ? null
                          : () => adicionarAoCarrinho(lote),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Adicionar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: esgotado || processandoCompra
                          ? null
                          : () => comprarAgora(lote),
                      icon: const Icon(Icons.flash_on),
                      label: const Text('Comprar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                      ),
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

  Widget estadoErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 60),
            const SizedBox(height: 14),
            Text(
              erro ?? 'Erro ao carregar evento',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: carregarDados,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget estadoVazioLotes() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            Icons.local_activity_outlined,
            size: 54,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'Nenhum lote disponível',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Este evento ainda não possui lotes cadastrados.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ev = evento;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro != null || ev == null
          ? estadoErro()
          : RefreshIndicator(
              onRefresh: carregarDados,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 290,
                    pinned: true,
                    backgroundColor: const Color(0xFF111111),
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      title: Text(
                        ev.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          ev.bannerUrl.trim().isNotEmpty
                              ? Image.network(
                                  ev.bannerUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: Colors.grey.shade300,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      size: 48,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey.shade300,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    size: 48,
                                  ),
                                ),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black54,
                                  Colors.black87,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ev.titulo,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          linhaInfo(
                            icone: Icons.calendar_month_outlined,
                            titulo: 'Início',
                            valor: formatarDataHora(ev.dataInicio),
                          ),
                          linhaInfo(
                            icone: Icons.event_outlined,
                            titulo: 'Fim',
                            valor: formatarDataHora(ev.dataFim),
                          ),
                          linhaInfo(
                            icone: Icons.location_on_outlined,
                            titulo: 'Local',
                            valor: ev.local,
                          ),
                          linhaInfo(
                            icone: Icons.map_outlined,
                            titulo: 'Endereço',
                            valor: ev.endereco,
                          ),
                          linhaInfo(
                            icone: Icons.storefront_outlined,
                            titulo: 'Promovido por',
                            valor: ev.nomeLoja.isEmpty
                                ? widget.loja.nome
                                : ev.nomeLoja,
                          ),
                          if (ev.nomeCidade.trim().isNotEmpty)
                            linhaInfo(
                              icone: Icons.location_city_outlined,
                              titulo: 'Cidade',
                              valor: ev.nomeCidade,
                            ),
                          if (ev.descricao.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Descrição',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Text(
                                ev.descricao,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade800,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          const Text(
                            'Lotes',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (lotes.isEmpty)
                            estadoVazioLotes()
                          else
                            ...lotes.map(cardLote),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
