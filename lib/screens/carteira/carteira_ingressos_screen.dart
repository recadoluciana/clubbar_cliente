import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/carteira_badge_notifier.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../services/api_service.dart';

class CarteiraIngressosScreen extends StatefulWidget {
  final String nomeLoja;
  final String logoLoja;
  final String nomeCliente;
  final List<Map<String, dynamic>> itens;
  final Future<List<Map<String, dynamic>>> Function()? onAtualizar;
  final VoidCallback onVoltar;

  const CarteiraIngressosScreen({
    super.key,
    required this.nomeLoja,
    required this.logoLoja,
    required this.nomeCliente,
    required this.itens,
    required this.onAtualizar,
    required this.onVoltar,
  });

  @override
  State<CarteiraIngressosScreen> createState() =>
      _CarteiraIngressosScreenState();
}

class _CarteiraIngressosScreenState extends State<CarteiraIngressosScreen> {
  late List<Map<String, dynamic>> itensTela;
  final ApiService apiService = ApiService();

  static const String baseUrl = 'https://bitbeer-production.up.railway.app';

  @override
  void initState() {
    super.initState();
    itensTela = List<Map<String, dynamic>>.from(widget.itens);
  }

  bool _isIngresso(Map<String, dynamic> item) {
    return (item['idtipoproduto'] ?? '').toString().toUpperCase() == 'I';
  }

  String _valor(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    return 'R\$ ${n.toStringAsFixed(2)}';
  }

  String _formatarCpf(String cpf) {
    final numeros = cpf.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length != 11) return cpf;

    return '${numeros.substring(0, 3)}.'
        '${numeros.substring(3, 6)}.'
        '${numeros.substring(6, 9)}-'
        '${numeros.substring(9, 11)}';
  }

  String _buildImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }

  Future<void> _abrirDialogAlterarParticipante(
    Map<String, dynamic> item,
  ) async {
    final nomeController = TextEditingController(
      text: (item['nmparticipante'] ?? '').toString(),
    );

    final cpfController = TextEditingController(
      text: _formatarCpf((item['cpfparticipante'] ?? '').toString()),
    );

    final resultado = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text('Alterar participante'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome do participante',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cpfController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'CPF do participante',
                  border: OutlineInputBorder(),
                ),
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
                final cpf = cpfController.text.replaceAll(
                  RegExp(r'[^0-9]'),
                  '',
                );

                if (nome.isEmpty || cpf.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Informe nome e CPF do participante.'),
                    ),
                  );
                  return;
                }

                if (cpf.length != 11) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CPF inválido.')),
                  );
                  return;
                }

                Navigator.pop(context, {'nome': nome, 'cpf': cpf});
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    nomeController.dispose();
    cpfController.dispose();

    if (resultado == null) return;

    try {
      final itvendaId = int.tryParse('${item['itvenda_id'] ?? 0}') ?? 0;

      if (itvendaId == 0) {
        throw Exception('Item da venda inválido');
      }

      await apiService.alterarParticipanteItVenda(
        itvendaId: itvendaId,
        nmparticipante: resultado['nome']!,
        cpfparticipante: resultado['cpf']!,
      );

      if (!mounted) return;

      setState(() {
        item['nmparticipante'] = resultado['nome'];
        item['cpfparticipante'] = resultado['cpf'];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Participante alterado com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _abrirQrOuRetirada(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final codigo = (item['itvenda_id'] ?? '').toString();

    final qrData = jsonEncode({
      'itvenda_id': codigo,
      'nmloja': widget.nomeLoja,
      'nmcliente': (item['nmcliente'] ?? '').toString(),
      'nmproduto': (item['nmproduto'] ?? '').toString(),
      'nmparticipante': (item['nmparticipante'] ?? '').toString(),
      'cpfparticipante': (item['cpfparticipante'] ?? '').toString(),
      'urlfotoproduto': (item['urlfotoproduto'] ?? '').toString(),
    });

    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR Code não disponível para este item')),
      );
      return;
    }

    await showDialog(
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
                  'Validação do ingresso',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  (item['nmproduto'] ?? '').toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if ((item['nmparticipante'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          (item['nmparticipante'] ?? '').toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          _formatarCpf(
                            item['cpfparticipante'] ?? '',
                          ).toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Apresente este QR Code na portaria.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                QrImageView(
                  data: qrData,
                  size: 220,
                  backgroundColor: Colors.white,
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

    // atualizar itens e badge após retirada ou fechamento do qr
    if (widget.onAtualizar != null) {
      final novosItens = await widget.onAtualizar!();

      CarteiraBadgeNotifier.atualizar();

      if (!mounted) return;

      setState(() {
        itensTela = novosItens;
      });
    }
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
    final nomeParticipante = (item['nmparticipante'] ?? '').toString();
    final cpfParticipante = _formatarCpf(
      (item['cpfparticipante'] ?? '').toString(),
    );
    final validade = (item['dtexpiraitvenda_fmt'] ?? '').toString();

    //debugPrint('ITEM CARTEIRA INGRESSO => $item');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _imagemItem(item),
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
                          _chip('Valor: ${_valor(item['vrunititvenda'])}'),
                          if (validade.isNotEmpty) _chip('Validade: $validade'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (nomeParticipante.isNotEmpty ||
                          cpfParticipante.isNotEmpty) ...[
                        const SizedBox(height: 10),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.20),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (nomeParticipante.isNotEmpty)
                                Text(
                                  nomeParticipante,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),

                              if (cpfParticipante.isNotEmpty) ...[
                                const SizedBox(height: 4),

                                Text(
                                  cpfParticipante,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () =>
                                    _abrirDialogAlterarParticipante(item),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_outlined, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'Alterar',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: () => _abrirQrOuRetirada(context, item),
                          icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                          label: const Text('Retirar ingresso'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF7A5A00),
                            side: const BorderSide(color: Color(0xFFE0C36A)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
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

  Widget _imagemItem(Map<String, dynamic> item) {
    final url = _buildImageUrl((item['urlfotoproduto'] ?? '').toString());

    if (url.isEmpty) {
      return _placeholderItem(item);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholderItem(item),
      ),
    );
  }

  Widget _placeholderItem(Map<String, dynamic> item) {
    return Container(
      width: 72,
      height: 72,
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

  Widget _cabecalho(int totalUnidades) {
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
          SizedBox(width: 92, height: 92, child: _logoLoja()),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Carteira - Ingressos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  widget.nomeLoja,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalUnidades ingresso(s) disponível(is)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoLoja() {
    if (widget.logoLoja.isEmpty) {
      return Container(
        width: 92,
        height: 92,
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
        widget.logoLoja,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
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
    final totalUnidades = itensTela.fold<int>(
      0,
      (total, item) => total + (int.tryParse('${item['qtitvenda'] ?? 0}') ?? 0),
    );

    return Scaffold(
      appBar: ClubbarAppBar(mostrarVoltar: true, onVoltar: widget.onVoltar),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          _cabecalho(totalUnidades),
          const SizedBox(height: 22),
          if (itensTela.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text(
                  'Nenhum ingresso disponível para uso neste estabelecimento',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            ...itensTela.map((item) => _itemCard(context, item)),
        ],
      ),
    );
  }
}
