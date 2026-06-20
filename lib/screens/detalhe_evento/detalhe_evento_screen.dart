import 'package:flutter/material.dart';

import '../../models/evento_detalhe.dart';
import '../../models/evento_lote.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../utils/date_formatters.dart';
import '../pagamento/escolha_pagamento_screen.dart';
import '../produtos_loja/produtos_loja_screen.dart';
import '../../services/main_navigation_controller.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../services/cart_badge_notifier.dart';
import '../../utils/cpf_utils.dart';
import 'package:share_plus/share_plus.dart';

class DetalheEventoScreen extends StatefulWidget {
  final int eventoId;
  final Loja loja;
  final VoidCallback? onVoltar;

  const DetalheEventoScreen({
    super.key,
    required this.eventoId,
    required this.loja,
    this.onVoltar,
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

  Future<void> compartilharEvento() async {
    final ev = evento;
    if (ev == null) return;

    final texto =
        '''
  ${ev.titulo}

  Data: ${formatarDataHora(ev.dataInicio)}
  Local: ${ev.local}
  Endereço: ${ev.endereco}
  Cidade: ${ev.nomeCidade}${ev.sgEstado.trim().isEmpty ? '' : ' - ${ev.sgEstado}'}

  Confira no Clubbar!
  ''';

    await Share.share(texto);
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
      final participante = await pedirParticipante();

      if (participante == null) return;

      await apiService.adicionarAoCarrinho(
        clienteId: clienteId,
        organizacaoId: widget.loja.organizacaoId,
        lojaId: widget.loja.id,
        produtoId: null,
        loteId: lote.loteId,
        idtipoproduto: 'I',
        quantidade: 1,
        observacao: 'Ingresso ${lote.nome}',
        nmparticipante: participante['nome'],
        cpfparticipante: participante['cpf'],
      );

      final totalCarrinho = await apiService.buscarQuantidadeCarrinho(
        clienteId: clienteId,
      );

      CartBadgeNotifier.atualizar(totalCarrinho);

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

  Future<Map<String, String>?> pedirParticipante() async {
    final nomeController = TextEditingController();
    final cpfController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text('Dados do participante'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cpfController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'CPF'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final nome = nomeController.text.trim();

                if (nome.isEmpty || cpfController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Informe nome e CPF do participante'),
                    ),
                  );
                  return;
                }

                if (!CpfUtils.validar(cpfController.text)) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('CPF inválido')));
                  return;
                }

                final cpfLimpo = CpfUtils.somenteNumeros(cpfController.text);

                Navigator.pop(context, {'nome': nome, 'cpf': cpfLimpo});
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> comprarAgora(EventoLote lote) async {
    if (processandoCompra) return;

    setState(() {
      processandoCompra = true;
    });

    try {
      final clienteId = await authStorage.obterClienteId();

      if (clienteId == null || clienteId == 0) {
        throw Exception('Faça login para comprar');
      }

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

      MainNavigationController.abrirTela(
        EscolhaPagamentoScreen(
          loja: widget.loja,
          totalProdutos: 0,
          totalIngressos: lote.preco,
          onVoltar: () {
            MainNavigationController.abrirTela(
              DetalheEventoScreen(eventoId: widget.eventoId, loja: widget.loja),
            );
          },
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
    final percentualVendido = total <= 0 ? 0.0 : vendidosAjustado / total;

    Color cor;
    if (percentualVendido >= 0.9) {
      cor = Colors.red;
    } else if (percentualVendido >= 0.6) {
      cor = Colors.orange;
    } else {
      cor = Colors.green;
    }

    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: percentualVendido,
            strokeWidth: 7,
            backgroundColor: Colors.grey.withOpacity(0.18),
            valueColor: AlwaysStoppedAnimation<Color>(cor),
          ),
          Text(
            '$vendidosAjustado',
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
                  Column(
                    children: [
                      miniGraficoLote(
                        total: lote.qtTotal,
                        vendidos: lote.qtVendida,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${lote.qtVendida}/${lote.qtTotal}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
      appBar: ClubbarAppBar(mostrarVoltar: true, onVoltar: widget.onVoltar),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro != null || ev == null
          ? estadoErro()
          : RefreshIndicator(
              onRefresh: carregarDados,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 260,
                            width: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: ev.bannerUrl.trim().isNotEmpty
                                ? Image.network(ev.bannerUrl, fit: BoxFit.cover)
                                : Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      size: 48,
                                    ),
                                  ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -22),
                            child: Center(
                              child: ElevatedButton.icon(
                                onPressed: compartilharEvento,
                                icon: const Icon(Icons.ios_share, size: 18),
                                label: const Text('COMPARTILHAR'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue,
                                  elevation: 4,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
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
                            titulo: 'Data',
                            valor: formatarDataHora(ev.dataInicio),
                          ),
                          linhaInfo(
                            icone: Icons.location_on_outlined,
                            titulo: 'Local',
                            valor: ev.local,
                          ),
                          linhaInfo(
                            icone: Icons.map_outlined,
                            titulo: 'Endereço',
                            valor: ev.bairro.trim().isEmpty
                                ? ev.endereco
                                : '${ev.bairro} - ${ev.endereco}',
                          ),
                          if (ev.nomeCidade.trim().isNotEmpty)
                            linhaInfo(
                              icone: Icons.location_city_outlined,
                              titulo: 'Cidade',
                              valor: ev.sgEstado.trim().isEmpty
                                  ? ev.nomeCidade
                                  : '${ev.nomeCidade} - ${ev.sgEstado}',
                            ),

                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Lotes',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  MainNavigationController.abrirTela(
                                    ProdutosLojaScreen(
                                      loja: widget.loja,
                                      onVoltar: () {
                                        MainNavigationController.abrirTela(
                                          DetalheEventoScreen(
                                            eventoId: widget.eventoId,
                                            loja: widget.loja,
                                            onVoltar: widget.onVoltar,
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 18,
                                ),
                                label: const Text('Comprar produto'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          if (lotes.isEmpty)
                            estadoVazioLotes()
                          else
                            ...lotes.map(cardLote),
                          const SizedBox(height: 24),
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
