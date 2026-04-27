import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../utils/value_formatters.dart';

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
      lojaSelecionada = null;
    });

    try {
      final idCliente = await authStorage.obterClienteId();

      if (idCliente == null || idCliente == 0) {
        throw Exception('Cliente não identificado. Faça login novamente.');
      }

      clienteId = idCliente;

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
    if (carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (lojaSelecionada != null) {
      return CarteiraLojaScreen(
        nomeLoja: lojaSelecionada!['nomeLoja'],
        logoLoja: lojaSelecionada!['logoLoja'],
        itens: List<Map<String, dynamic>>.from(lojaSelecionada!['itens']),
        onVoltar: () {
          setState(() {
            lojaSelecionada = null;
          });
        },
      );
    }

    return _listaCarteira();
  }
}

class CarteiraLojaScreen extends StatelessWidget {
  final String nomeLoja;
  final String logoLoja;
  final List<Map<String, dynamic>> itens;
  final VoidCallback onVoltar;

  const CarteiraLojaScreen({
    super.key,
    required this.nomeLoja,
    required this.logoLoja,
    required this.itens,
    required this.onVoltar,
  });

  bool _isIngresso(Map<String, dynamic> item) {
    return (item['idtipoproduto'] ?? '').toString().toUpperCase() == 'I';
  }

  String _valor(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    return 'R\$ ${n.toStringAsFixed(2)}';
  }

  static const String baseUrl = 'https://bitbeer-production.up.railway.app';

  String _buildImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }

  Widget _badgeTipo(Map<String, dynamic> item) {
    final ingresso = _isIngresso(item);
    final cor = ingresso ? Colors.blue : Colors.amber.shade800;
    final fundo = ingresso
        ? Colors.blue.withOpacity(0.10)
        : Colors.amber.withOpacity(0.15);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        ingresso ? 'Ingresso' : 'Produto',
        style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  void _abrirQrOuRetirada(BuildContext context, Map<String, dynamic> item) {
    final codigo = (item['itvenda_id'] ?? '').toString();

    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR Code não disponível para este item')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Retirada do produto',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Apresente este QR Code no balcão',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                QrImageView(
                  data: codigo,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  codigo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _itemCard(BuildContext context, Map<String, dynamic> item) {
    final obs = (item['dsobsitvenda'] ?? '').toString();
    final validade = (item['dtexpiraitvenda_fmt'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _abrirQrOuRetirada(context, item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (_) {
                    final path = (item['urlfotoproduto'] ?? '').toString();
                    final url = _buildImageUrl(path);

                    if (url.isEmpty) {
                      return Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          _isIngresso(item)
                              ? Icons.confirmation_number_outlined
                              : Icons.local_bar_outlined,
                          color: Colors.amber.shade800,
                          size: 30,
                        ),
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
                              _isIngresso(item)
                                  ? Icons.confirmation_number_outlined
                                  : Icons.local_bar_outlined,
                              color: Colors.amber.shade800,
                              size: 30,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (item['nmproduto'] ?? '').toString(),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _badgeTipo(item),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip('Qtd: ${item['qtitvenda'] ?? 0}'),
                          _chip('Valor: ${_valor(item['vrunititvenda'])}'),
                          if (validade.isNotEmpty) _chip('Validade: $validade'),
                        ],
                      ),
                      if (obs.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Observação: $obs',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => _abrirQrOuRetirada(context, item),
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: const Text('Retirar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoLoja() {
    if (logoLoja.isEmpty) {
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
        logoLoja,
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

  @override
  Widget build(BuildContext context) {
    final totalUnidades = itens.fold<int>(
      0,
      (total, item) => total + (int.tryParse('${item['qtitvenda'] ?? 0}') ?? 0),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Row(
          children: [
            IconButton(onPressed: onVoltar, icon: const Icon(Icons.arrow_back)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                nomeLoja,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              _logoLoja(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomeLoja,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$totalUnidades item(ns) disponível(is) para retirada',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...itens.map((item) => _itemCard(context, item)),
      ],
    );
  }
}
