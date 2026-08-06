import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../services/main_navigation_controller.dart';
import '../../services/carteira_badge_notifier.dart';
import 'carteira_loja_screen.dart';
import 'carteira_ingressos_screen.dart';
import '../../widgets/clubbar_page_header.dart';
import 'package:clubbar_cliente/config/app_config.dart';

class CarteiraScreen extends StatefulWidget {
  const CarteiraScreen({super.key});

  @override
  State<CarteiraScreen> createState() => _CarteiraScreenState();
}

class _CarteiraScreenState extends State<CarteiraScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();

  static final String baseUrl = AppConfig.apiBaseUrl;

  bool carregando = true;
  String? erro;
  int? clienteId;
  String nomeCliente = '';

  List<Map<String, dynamic>> itensPendentes = [];
  List<Map<String, dynamic>> lojasResumo = [];

  @override
  void initState() {
    super.initState();
    carregarTela();
  }

  Future<void> carregarTela() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final idCliente = await authStorage.obterClienteId();

      if (idCliente == null || idCliente == 0) {
        throw Exception('Cliente não identificado. Faça login novamente.');
      }

      clienteId = idCliente;
      nomeCliente = await authStorage.obterNmcliente() ?? 'não identificado';

      final itens = await apiService.buscarPendentes(
        clienteId: idCliente,
        lojaId: 0,
      );

      final resumo = _agruparPorLoja(itens);

      setState(() {
        itensPendentes = itens;
        lojasResumo = resumo;
        carregando = false;
      });

      CarteiraBadgeNotifier.atualizar();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        erro = apiService.mensagemErroAmigavel(e);
        itensPendentes = [];
        lojasResumo = [];
        carregando = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> recarregarItensDaLoja(
    int lojaId, {
    String? tipo,
  }) async {
    if (clienteId == null) return [];

    final itens = await apiService.buscarPendentes(
      clienteId: clienteId!,
      lojaId: 0,
    );

    final resumo = _agruparPorLoja(itens);

    if (mounted) {
      setState(() {
        itensPendentes = itens;
        lojasResumo = resumo;
      });
    }

    CarteiraBadgeNotifier.atualizar();

    final lojaAtualizada = resumo.where((l) => l['loja_id'] == lojaId).toList();

    if (lojaAtualizada.isEmpty) {
      return [];
    }

    final itensLoja = List<Map<String, dynamic>>.from(
      lojaAtualizada.first['itens'],
    );

    if (tipo == 'I') {
      return itensLoja.where((item) {
        return (item['idtipoproduto'] ?? '').toString().toUpperCase() == 'I';
      }).toList();
    }

    if (tipo == 'P') {
      return itensLoja.where((item) {
        return (item['idtipoproduto'] ?? '').toString().toUpperCase() != 'I';
      }).toList();
    }

    return itensLoja;
  }

  List<Map<String, dynamic>> _agruparPorLoja(List<Map<String, dynamic>> itens) {
    final Map<int, Map<String, dynamic>> agrupado = {};

    for (final item in itens) {
      final lojaId = int.tryParse('${item['loja_id'] ?? 0}') ?? 0;
      final nomeLoja = (item['nmloja'] ?? 'Loja').toString();
      final logoLoja = (item['urllogoloja'] ?? '').toString();
      final qtd = int.tryParse('${item['qtitvenda'] ?? 0}') ?? 0;

      if (!agrupado.containsKey(lojaId)) {
        agrupado[lojaId] = {
          'loja_id': lojaId,
          'nmloja': nomeLoja,
          'urllogoloja': logoLoja,
          'total_itens': 0,
          'itens': <Map<String, dynamic>>[],
          'total_produtos': 0,
          'total_ingressos': 0,
        };
      }

      agrupado[lojaId]!['total_itens'] =
          (agrupado[lojaId]!['total_itens'] as int) + qtd;

      final tipo = (item['idtipoproduto'] ?? '').toString().toUpperCase();

      if (tipo == 'I') {
        agrupado[lojaId]!['total_ingressos'] =
            (agrupado[lojaId]!['total_ingressos'] as int) + qtd;
      } else {
        agrupado[lojaId]!['total_produtos'] =
            (agrupado[lojaId]!['total_produtos'] as int) + qtd;
      }

      (agrupado[lojaId]!['itens'] as List<Map<String, dynamic>>).add(item);
    }

    return agrupado.values.toList();
  }

  String _buildImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }

  Widget _logoLoja(String url) {
    Widget placeholder() {
      return Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.14),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.amber.shade200, width: 2),
        ),
        child: Icon(
          Icons.storefront_rounded,
          color: Colors.amber.shade800,
          size: 30,
        ),
      );
    }

    if (url.trim().isEmpty) {
      return placeholder();
    }

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          url,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder(),
        ),
      ),
    );
  }

  Widget _cardLoja(Map<String, dynamic> loja) {
    final nome = (loja['nmloja'] ?? 'Loja').toString();
    final logo = _buildImageUrl((loja['urllogoloja'] ?? '').toString());

    final itens = List<Map<String, dynamic>>.from(loja['itens'] as List);

    final lojaId = int.tryParse('${loja['loja_id'] ?? 0}') ?? 0;

    final produtos = itens.where((item) {
      return (item['idtipoproduto'] ?? '').toString().trim().toUpperCase() !=
          'I';
    }).toList();

    final ingressos = itens.where((item) {
      return (item['idtipoproduto'] ?? '').toString().trim().toUpperCase() ==
          'I';
    }).toList();

    final totalProdutos = int.tryParse('${loja['total_produtos'] ?? 0}') ?? 0;

    final totalIngressos = int.tryParse('${loja['total_ingressos'] ?? 0}') ?? 0;

    final totalLoja = totalProdutos + totalIngressos;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.15),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  _logoLoja(logo),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          totalLoja == 1
                              ? '1 item disponível'
                              : '$totalLoja itens disponíveis',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$totalLoja',
                      style: const TextStyle(
                        color: Color(0xFF755600),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  _atalhoCarteira(
                    titulo: 'Produtos',
                    quantidade: totalProdutos,
                    icone: Icons.shopping_bag_rounded,
                    cor: const Color(0xFFD18A00),
                    onTap: () {
                      MainNavigationController.abrirTela(
                        CarteiraLojaScreen(
                          nomeLoja: nome,
                          logoLoja: logo,
                          nomeCliente: nomeCliente,
                          itens: produtos,
                          onAtualizar: () =>
                              recarregarItensDaLoja(lojaId, tipo: 'P'),
                          onVoltar: () {
                            MainNavigationController.fecharTelaInterna();
                          },
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 10),

                  _atalhoCarteira(
                    titulo: 'Ingressos',
                    quantidade: totalIngressos,
                    icone: Icons.confirmation_number_rounded,
                    cor: Colors.blue,
                    onTap: () {
                      MainNavigationController.abrirTela(
                        CarteiraIngressosScreen(
                          nomeLoja: nome,
                          logoLoja: logo,
                          nomeCliente: nomeCliente,
                          itens: ingressos,
                          onAtualizar: () =>
                              recarregarItensDaLoja(lojaId, tipo: 'I'),
                          onVoltar: () {
                            MainNavigationController.fecharTelaInterna();
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoCarteira({
    required String texto,
    required bool ativo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: ativo ? onTap : null,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: ativo ? const Color(0xFFFFF4E3) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(22),
          boxShadow: ativo
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                texto,
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: ativo ? const Color(0xFF7A5A00) : Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            if (ativo)
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF7A5A00),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _estadoVazio() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          const Text(
            'Sua carteira está vazia',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _erroWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 56),
          const SizedBox(height: 14),
          Text(
            erro ?? 'Erro ao carregar carteira',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: carregarTela,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _listaCarteira() {
    return Column(
      children: [
        ClubbarPageHeader(
          titulo: 'Carteira',
          subtitulo: 'Produtos e ingressos disponíveis para você usar',
          icone: Icons.account_balance_wallet_rounded,
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: carregarTela,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                if (erro != null)
                  _erroWidget()
                else if (lojasResumo.isEmpty)
                  _estadoVazio()
                else
                  ...lojasResumo.map(_cardLoja),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _atalhoCarteira({
    required String titulo,
    required int quantidade,
    required IconData icone,
    required Color cor,
    required VoidCallback onTap,
  }) {
    final ativo = quantidade > 0;

    return Expanded(
      child: Material(
        color: ativo ? cor.withOpacity(0.10) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: ativo ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 113,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: ativo ? cor.withOpacity(0.30) : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: ativo ? cor.withOpacity(0.16) : Colors.white,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        icone,
                        size: 20,
                        color: ativo ? cor : Colors.grey.shade400,
                      ),
                    ),
                    const Spacer(),
                    if (ativo)
                      Icon(Icons.chevron_right_rounded, size: 22, color: cor),
                  ],
                ),

                const SizedBox(height: 9),

                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ativo ? Colors.black87 : Colors.grey.shade500,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  quantidade == 1 ? '1 item' : '$quantidade itens',
                  style: TextStyle(
                    color: ativo ? cor : Colors.grey.shade400,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : _listaCarteira(),
    );
  }
}
