import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../utils/value_formatters.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../services/main_navigation_controller.dart';
import '../../services/carteira_badge_notifier.dart';
import 'carteira_loja_screen.dart';

class CarteiraScreen extends StatefulWidget {
  const CarteiraScreen({super.key});

  @override
  State<CarteiraScreen> createState() => _CarteiraScreenState();
}

class _CarteiraScreenState extends State<CarteiraScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();

  Map<String, dynamic>? lojaSelecionada;

  static const String baseUrl = 'https://bitbeer-production.up.railway.app';

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

  Future<void> atualizarMantendoLoja() async {
    if (clienteId == null || lojaSelecionada == null) {
      await carregarTela();
      return;
    }

    final nomeLojaAtual = lojaSelecionada!['nomeLoja'];

    final itens = await apiService.buscarPendentes(
      clienteId: clienteId!,
      lojaId: 0,
    );

    final resumo = _agruparPorLoja(itens);

    final lojaAtualizada = resumo
        .where((l) => l['nmloja'] == nomeLojaAtual)
        .cast<Map<String, dynamic>>()
        .toList();

    setState(() {
      itensPendentes = itens;
      lojasResumo = resumo;

      if (lojaAtualizada.isNotEmpty) {
        lojaSelecionada = {
          'nomeLoja': lojaAtualizada.first['nmloja'],
          'logoLoja': _buildImageUrl(
            (lojaAtualizada.first['urllogoloja'] ?? '').toString(),
          ),
          'itens': lojaAtualizada.first['itens'],
        };
      } else {
        lojaSelecionada = null;
      }
    });
    CarteiraBadgeNotifier.atualizar();
  }

  Future<void> carregarTela() async {
    setState(() {
      carregando = true;
      erro = null;
      lojaSelecionada = null;
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
    } catch (e) {
      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '');
        itensPendentes = [];
        lojasResumo = [];
        carregando = false;
      });
    }
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
        };
      }

      agrupado[lojaId]!['total_itens'] =
          (agrupado[lojaId]!['total_itens'] as int) + qtd;

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
    if (url.isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.storefront_outlined, color: Colors.amber.shade800),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        url,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.storefront_outlined,
              color: Colors.amber.shade800,
            ),
          );
        },
      ),
    );
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
                  'Itens comprados por local.',
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
    final totalItens = int.tryParse('${loja['total_itens'] ?? 0}') ?? 0;
    final itens = List<Map<String, dynamic>>.from(loja['itens'] as List);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            setState(() {
              lojaSelecionada = {
                'nomeLoja': nome,
                'logoLoja': logo,
                'itens': itens,
              };
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                _logoLoja(logo),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${ValueFormatters.numero(totalItens)} item(ns) para retirar',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 32),
              ],
            ),
          ),
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Stack(
          children: [
            const ClubbarAppBar(),

            Positioned(
              left: 8,
              top: 8,
              bottom: 8,
              child: IconButton(
                onPressed: () {
                  if (lojaSelecionada != null) {
                    setState(() {
                      lojaSelecionada = null;
                    });
                  } else {
                    MainNavigationController.irParaHome();
                  }
                },
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),

      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : lojaSelecionada != null
          ? CarteiraLojaScreen(
              nomeLoja: lojaSelecionada!['nomeLoja'],
              logoLoja: lojaSelecionada!['logoLoja'],
              nomeCliente: nomeCliente,
              itens: List<Map<String, dynamic>>.from(lojaSelecionada!['itens']),
              onAtualizar: atualizarMantendoLoja,
              onVoltar: () {
                setState(() {
                  lojaSelecionada = null;
                });
              },
            )
          : _listaCarteira(),
    );
  }
}
