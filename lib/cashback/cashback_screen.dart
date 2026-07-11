import 'package:flutter/material.dart';

import '../../utils/value_formatters.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/clubbar_page_header.dart';

enum CashbackStatus { disponivel, pendente, utilizado, expirado }

enum CashbackTipoMovimento { credito, debito }

class CashbackMovimentoMock {
  final int id;
  final int lojaId;
  final String nomeLoja;
  final String descricao;
  final double valor;
  final CashbackTipoMovimento tipo;
  final CashbackStatus status;
  final DateTime dataMovimento;
  final DateTime? dataLiberacao;
  final DateTime? dataValidade;
  final String? observacao;

  const CashbackMovimentoMock({
    required this.id,
    required this.lojaId,
    required this.nomeLoja,
    required this.descricao,
    required this.valor,
    required this.tipo,
    required this.status,
    required this.dataMovimento,
    this.dataLiberacao,
    this.dataValidade,
    this.observacao,
  });
}

class CashbackScreen extends StatefulWidget {
  const CashbackScreen({super.key});

  @override
  State<CashbackScreen> createState() => _CashbackScreenState();
}

class _CashbackScreenState extends State<CashbackScreen> {
  String filtroSelecionado = 'TODOS';

  final List<CashbackMovimentoMock> movimentos = [
    CashbackMovimentoMock(
      id: 1,
      lojaId: 2,
      nomeLoja: 'Forró do X',
      descricao: 'Cashback da compra #245',
      valor: 3.50,
      tipo: CashbackTipoMovimento.credito,
      status: CashbackStatus.disponivel,
      dataMovimento: DateTime(2026, 7, 8, 22, 46),
      dataLiberacao: DateTime(2026, 7, 8, 22, 46),
      dataValidade: DateTime(2026, 10, 8),
    ),
    CashbackMovimentoMock(
      id: 2,
      lojaId: 1,
      nomeLoja: 'Bar da Cida',
      descricao: 'Cashback da compra #239',
      valor: 7.25,
      tipo: CashbackTipoMovimento.credito,
      status: CashbackStatus.pendente,
      dataMovimento: DateTime(2026, 7, 7, 20, 30),
      dataLiberacao: DateTime(2026, 7, 10),
      dataValidade: DateTime(2026, 10, 10),
      observacao: 'Será liberado após a confirmação da compra.',
    ),
    CashbackMovimentoMock(
      id: 3,
      lojaId: 3,
      nomeLoja: 'Motor Rock',
      descricao: 'Cashback utilizado na compra #232',
      valor: 5.00,
      tipo: CashbackTipoMovimento.debito,
      status: CashbackStatus.utilizado,
      dataMovimento: DateTime(2026, 7, 5, 23, 15),
    ),
    CashbackMovimentoMock(
      id: 4,
      lojaId: 2,
      nomeLoja: 'Forró do X',
      descricao: 'Cashback da compra #210',
      valor: 2.80,
      tipo: CashbackTipoMovimento.credito,
      status: CashbackStatus.expirado,
      dataMovimento: DateTime(2026, 3, 10, 19, 20),
      dataLiberacao: DateTime(2026, 3, 10),
      dataValidade: DateTime(2026, 6, 10),
    ),
  ];

  double get saldoDisponivel {
    return movimentos
        .where(
          (m) =>
              m.tipo == CashbackTipoMovimento.credito &&
              m.status == CashbackStatus.disponivel,
        )
        .fold<double>(0, (soma, item) => soma + item.valor);
  }

  double get saldoPendente {
    return movimentos
        .where(
          (m) =>
              m.tipo == CashbackTipoMovimento.credito &&
              m.status == CashbackStatus.pendente,
        )
        .fold<double>(0, (soma, item) => soma + item.valor);
  }

  double get totalRecebido {
    return movimentos
        .where((m) => m.tipo == CashbackTipoMovimento.credito)
        .fold<double>(0, (soma, item) => soma + item.valor);
  }

  List<CashbackMovimentoMock> get movimentosFiltrados {
    if (filtroSelecionado == 'TODOS') {
      return movimentos;
    }

    return movimentos.where((movimento) {
      switch (filtroSelecionado) {
        case 'DISPONIVEL':
          return movimento.status == CashbackStatus.disponivel;
        case 'PENDENTE':
          return movimento.status == CashbackStatus.pendente;
        case 'UTILIZADO':
          return movimento.status == CashbackStatus.utilizado;
        case 'EXPIRADO':
          return movimento.status == CashbackStatus.expirado;
        default:
          return true;
      }
    }).toList();
  }

  String _formatarData(DateTime? data) {
    if (data == null) return '';

    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();

    return '$dia/$mes/$ano';
  }

  Color _corStatus(CashbackStatus status) {
    switch (status) {
      case CashbackStatus.disponivel:
        return Colors.green;
      case CashbackStatus.pendente:
        return Colors.orange;
      case CashbackStatus.utilizado:
        return Colors.blue;
      case CashbackStatus.expirado:
        return Colors.red;
    }
  }

  String _textoStatus(CashbackStatus status) {
    switch (status) {
      case CashbackStatus.disponivel:
        return 'Disponível';
      case CashbackStatus.pendente:
        return 'Pendente';
      case CashbackStatus.utilizado:
        return 'Utilizado';
      case CashbackStatus.expirado:
        return 'Expirado';
    }
  }

  IconData _iconeStatus(CashbackStatus status) {
    switch (status) {
      case CashbackStatus.disponivel:
        return Icons.check_circle_outline_rounded;
      case CashbackStatus.pendente:
        return Icons.hourglass_bottom_rounded;
      case CashbackStatus.utilizado:
        return Icons.shopping_cart_checkout_rounded;
      case CashbackStatus.expirado:
        return Icons.event_busy_rounded;
    }
  }

  Widget _cardSaldo({
    required String titulo,
    required double valor,
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icone, color: cor),
            ),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              ValueFormatters.moeda(valor),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumoCashback() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFC107), Color(0xFFFFE082)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.savings_rounded, size: 26),
                  SizedBox(width: 10),
                  Text(
                    'Saldo disponível',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                ValueFormatters.moeda(saldoDisponivel),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use este saldo nas próximas compras elegíveis.',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.65),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _cardSaldo(
              titulo: 'Pendente',
              valor: saldoPendente,
              icone: Icons.hourglass_bottom_rounded,
              cor: Colors.orange,
            ),
            const SizedBox(width: 12),
            _cardSaldo(
              titulo: 'Total recebido',
              valor: totalRecebido,
              icone: Icons.trending_up_rounded,
              cor: Colors.green,
            ),
          ],
        ),
      ],
    );
  }

  Widget _botaoFiltro({required String titulo, required String valor}) {
    final selecionado = filtroSelecionado == valor;

    return ChoiceChip(
      selected: selecionado,
      label: Text(titulo),
      onSelected: (_) {
        setState(() {
          filtroSelecionado = valor;
        });
      },
      selectedColor: Colors.amber,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: Colors.black,
        fontWeight: selecionado ? FontWeight.bold : FontWeight.w600,
      ),
      side: BorderSide(
        color: selecionado ? Colors.amber.shade700 : Colors.grey.shade300,
      ),
    );
  }

  Widget _filtros() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _botaoFiltro(titulo: 'Todos', valor: 'TODOS'),
          const SizedBox(width: 8),
          _botaoFiltro(titulo: 'Disponíveis', valor: 'DISPONIVEL'),
          const SizedBox(width: 8),
          _botaoFiltro(titulo: 'Pendentes', valor: 'PENDENTE'),
          const SizedBox(width: 8),
          _botaoFiltro(titulo: 'Utilizados', valor: 'UTILIZADO'),
          const SizedBox(width: 8),
          _botaoFiltro(titulo: 'Expirados', valor: 'EXPIRADO'),
        ],
      ),
    );
  }

  Widget _badgeStatus(CashbackStatus status) {
    final cor = _corStatus(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconeStatus(status), size: 15, color: cor),
          const SizedBox(width: 5),
          Text(
            _textoStatus(status),
            style: TextStyle(
              color: cor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardMovimento(CashbackMovimentoMock movimento) {
    final credito = movimento.tipo == CashbackTipoMovimento.credito;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: credito
                      ? Colors.green.withOpacity(0.10)
                      : Colors.blue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  credito
                      ? Icons.add_circle_outline_rounded
                      : Icons.remove_circle_outline_rounded,
                  color: credito ? Colors.green : Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movimento.nomeLoja,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      movimento.descricao,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${credito ? '+' : '-'} ${ValueFormatters.moeda(movimento.valor)}',
                style: TextStyle(
                  color: credito ? Colors.green.shade700 : Colors.blue.shade700,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _badgeStatus(movimento.status),
              const Spacer(),
              Text(
                _formatarData(movimento.dataMovimento),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          if (movimento.status == CashbackStatus.disponivel &&
              movimento.dataValidade != null) ...[
            const SizedBox(height: 10),
            Text(
              'Válido até ${_formatarData(movimento.dataValidade)}',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (movimento.status == CashbackStatus.pendente &&
              movimento.dataLiberacao != null) ...[
            const SizedBox(height: 10),
            Text(
              'Liberação prevista: ${_formatarData(movimento.dataLiberacao)}',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if ((movimento.observacao ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              movimento.observacao!,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _estadoVazio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(Icons.savings_outlined, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'Nenhum cashback encontrado',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _abrirRegrasCashback() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF6F6F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SizedBox(width: 44, child: Divider(thickness: 4)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Como funciona o cashback?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                const Text(
                  '• Parte do valor de compras elegíveis volta para você.\n\n'
                  '• O cashback pode ficar pendente até a confirmação da compra.\n\n'
                  '• O saldo disponível pode ser usado em novas compras.\n\n'
                  '• Cada cashback pode ter uma data de validade.\n\n'
                  '• Compras canceladas podem cancelar o cashback relacionado.',
                  style: TextStyle(fontSize: 15, height: 1.45),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = movimentosFiltrados;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Column(
        children: [
          const ClubbarPageHeader(
            titulo: 'Cashback',
            subtitulo: 'Seu saldo e histórico de recompensas',
            icone: Icons.savings_rounded,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              children: [
                _resumoCashback(),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Histórico',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _abrirRegrasCashback,
                      icon: const Icon(Icons.help_outline_rounded),
                      label: const Text('Como funciona'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _filtros(),
                const SizedBox(height: 18),
                if (lista.isEmpty)
                  _estadoVazio()
                else
                  ...lista.map(_cardMovimento),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
