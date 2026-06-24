import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../services/main_navigation_controller.dart';
import '../../services/carteira_badge_notifier.dart';
import 'carteira_loja_screen.dart';
import 'carteira_ingressos_screen.dart';

class CarteiraScreen extends StatefulWidget {
  const CarteiraScreen({super.key});

  @override
  State<CarteiraScreen> createState() => _CarteiraScreenState();
}

class _CarteiraScreenState extends State<CarteiraScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();

  static const String baseUrl = 'https://api.clubbar.com.br';

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
      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '');
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
    final imagem = url.isEmpty
        ? Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.storefront_outlined,
              color: Colors.amber.shade800,
            ),
          )
        : ClipOval(
            child: Image.network(
              url,
              width: 92,
              height: 92,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.storefront_outlined,
                    color: Colors.amber.shade800,
                  ),
                );
              },
            ),
          );

    return SizedBox(width: 120, child: Center(child: imagem));
  }

  Widget _cabecalho() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111111), Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 36,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Carteira',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Itens comprados por bar/casa noturna',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardLoja(Map<String, dynamic> loja) {
    final nome = (loja['nmloja'] ?? 'Loja').toString();
    final logo = _buildImageUrl((loja['urllogoloja'] ?? '').toString());
    final itens = List<Map<String, dynamic>>.from(loja['itens'] as List);
    final lojaId = int.tryParse('${loja['loja_id'] ?? 0}') ?? 0;

    final produtos = itens.where((item) {
      return (item['idtipoproduto'] ?? '').toString().toUpperCase() != 'I';
    }).toList();

    final ingressos = itens.where((item) {
      return (item['idtipoproduto'] ?? '').toString().toUpperCase() == 'I';
    }).toList();

    final totalProdutos = int.tryParse('${loja['total_produtos'] ?? 0}') ?? 0;
    final totalIngressos = int.tryParse('${loja['total_ingressos'] ?? 0}') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              _logoLoja(logo),

              Container(width: 1, height: 130, color: Colors.grey.shade300),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: _botaoCarteira(
                            texto: 'Produtos ($totalProdutos)',
                            ativo: produtos.isNotEmpty,
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
                        ),

                        const SizedBox(height: 6),

                        SizedBox(
                          width: double.infinity,
                          child: _botaoCarteira(
                            texto: 'Ingressos ($totalIngressos)',
                            ativo: ingressos.isNotEmpty,
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
                        ),
                      ],
                    ),
                  ],
                ),
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
    return RefreshIndicator(
      onRefresh: carregarTela,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          _cabecalho(),
          const SizedBox(height: 22),
          if (erro != null)
            _erroWidget()
          else if (lojasResumo.isEmpty)
            _estadoVazio()
          else
            ...lojasResumo.map(_cardLoja),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ClubbarAppBar(mostrarVoltar: true),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : _listaCarteira(),
    );
  }
}
