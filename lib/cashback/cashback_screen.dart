import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../utils/value_formatters.dart';
import '../widgets/clubbar_app_bar.dart';
import '../widgets/clubbar_page_header.dart';

class CashbackScreen extends StatefulWidget {
  const CashbackScreen({super.key});

  @override
  State<CashbackScreen> createState() => _CashbackScreenState();
}

class _CashbackScreenState extends State<CashbackScreen> {
  final _api = ApiService();
  final _auth = AuthStorage();
  Map<String, dynamic>? _dados;
  String? _erro;
  bool _carregando = true;
  String _filtro = 'TODOS';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final clienteId = await _auth.obterClienteId();
      if (clienteId == null || clienteId <= 0) {
        throw Exception('Cliente não autenticado.');
      }
      final dados = await _api.carteiraCashback(clienteId: clienteId);
      if (!mounted) return;
      setState(() => _dados = dados);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  double _numero(dynamic valor) => double.tryParse('$valor') ?? 0;

  List<Map<String, dynamic>> get _movimentos {
    final lista = (_dados?['movimentos'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    if (_filtro == 'TODOS') return lista;
    return lista.where((item) => item['status'] == _filtro).toList();
  }

  List<Map<String, dynamic>> get _saldosPorLoja =>
      (_dados?['saldos_por_loja'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where(
            (item) =>
                _numero(item['saldo_disponivel']) > 0 ||
                _numero(item['saldo_pendente']) > 0,
          )
          .toList();

  Color _corStatus(String status) => switch (status) {
    'DISPONIVEL' => Colors.green,
    'PENDENTE' => Colors.orange,
    'UTILIZADO' => Colors.blue,
    'EXPIRADO' || 'CANCELADO' => Colors.red,
    _ => Colors.grey,
  };

  String _textoStatus(String status) => switch (status) {
    'DISPONIVEL' => 'Disponível',
    'PENDENTE' => 'Pendente',
    'UTILIZADO' => 'Utilizado',
    'EXPIRADO' => 'Expirado',
    'CANCELADO' => 'Cancelado',
    _ => status,
  };

  Widget _saldo({
    required String titulo,
    required String valor,
    required String ajuda,
    required IconData icone,
    required Color cor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: cor),
            const SizedBox(height: 10),
            Text(titulo, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
              valor,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              ajuda,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumo() => Column(
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFC107), Color(0xFFFFE082)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Saldo disponível em todas as lojas',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              ValueFormatters.moeda(_numero(_dados?['saldo_disponivel'])),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Este é o total da sua carteira. Cada valor só pode ser usado na loja onde foi recebido.',
              style: TextStyle(height: 1.35),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          _saldo(
            titulo: 'A liberar',
            valor: ValueFormatters.moeda(_numero(_dados?['saldo_pendente'])),
            ajuda: 'Ainda não disponível',
            icone: Icons.hourglass_bottom_rounded,
            cor: Colors.orange,
          ),
          const SizedBox(width: 12),
          _saldo(
            titulo: 'Lojas com saldo',
            valor: '${_saldosPorLoja.length}',
            ajuda: _saldosPorLoja.length == 1
                ? 'estabelecimento'
                : 'estabelecimentos',
            icone: Icons.storefront_rounded,
            cor: Colors.green,
          ),
        ],
      ),
    ],
  );

  Widget _saldosDasLojas() {
    if (_saldosPorLoja.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Column(
          children: [
            Icon(Icons.savings_outlined, size: 34, color: Colors.black38),
            SizedBox(height: 8),
            Text(
              'Você ainda não possui cashback.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 4),
            Text(
              'Quando uma compra elegível gerar saldo, ele aparecerá aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seu saldo em cada loja',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'O cashback não é transferido entre estabelecimentos.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        ..._saldosPorLoja.map((item) {
          final disponivel = _numero(item['saldo_disponivel']);
          final pendente = _numero(item['saldo_pendente']);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.storefront_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['nome_loja'] ?? 'Loja'}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (pendente > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${ValueFormatters.moeda(pendente)} aguardando liberação',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      ValueFormatters.moeda(disponivel),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const Text(
                      'disponível',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _movimento(Map<String, dynamic> item) {
    final status = '${item['status'] ?? ''}';
    final credito = item['tipo'] == 'CREDITO';
    final cor = _corStatus(status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item['nome_loja'] ?? 'Loja'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _textoStatus(status),
                    style: TextStyle(
                      color: cor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${item['descricao'] ?? 'Movimento de cashback'}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item['data'] ?? ''}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
                Text(
                  '${credito ? '+' : '-'} ${ValueFormatters.moeda(_numero(item['valor']))}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: credito
                        ? Colors.green.shade700
                        : Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            if (item['validade'] != null &&
                '${item['validade']}'.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Validade: ${item['validade']}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Column(
        children: [
          const ClubbarPageHeader(
            titulo: 'Cashback',
            subtitulo: 'Visão geral do cashback em todas as lojas',
            icone: Icons.savings_rounded,
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _erro != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_erro!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _carregar,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _resumo(),
                        const SizedBox(height: 20),
                        _saldosDasLojas(),
                        const SizedBox(height: 22),
                        const Text(
                          'Histórico de movimentações',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Acompanhe os créditos, usos, liberações e cancelamentos.',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children:
                                [
                                      'TODOS',
                                      'DISPONIVEL',
                                      'PENDENTE',
                                      'UTILIZADO',
                                      'EXPIRADO',
                                      'CANCELADO',
                                    ]
                                    .map(
                                      (status) => Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(
                                            status == 'TODOS'
                                                ? 'Todos'
                                                : _textoStatus(status),
                                          ),
                                          selected: _filtro == status,
                                          onSelected: (_) =>
                                              setState(() => _filtro = status),
                                          selectedColor: Colors.amber,
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_movimentos.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(30),
                            child: Center(
                              child: Text('Nenhum movimento encontrado.'),
                            ),
                          )
                        else
                          ..._movimentos.map(_movimento),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
