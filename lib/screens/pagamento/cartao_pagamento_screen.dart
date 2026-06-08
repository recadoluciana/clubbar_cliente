import 'package:flutter/material.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import 'pagamento_sucesso_screen.dart';
import '../../services/carteira_badge_notifier.dart';
import '../main/main_navigation_screen.dart';
import '../../widgets/clubbar_app_bar.dart';

class CartaoPagamentoScreen extends StatefulWidget {
  final Loja loja;
  final String tipoPagamento;
  final double totalProdutos;
  final double taxaConveniencia;
  final double totalPagar;

  const CartaoPagamentoScreen({
    super.key,
    required this.loja,
    required this.tipoPagamento,
    required this.totalProdutos,
    required this.taxaConveniencia,
    required this.totalPagar,
  });

  @override
  State<CartaoPagamentoScreen> createState() => _CartaoPagamentoScreenState();
}

class _CartaoPagamentoScreenState extends State<CartaoPagamentoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _mesCtrl = TextEditingController();
  final _anoCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();

  final apiService = ApiService();
  final authStorage = AuthStorage();

  bool carregando = false;

  bool _anoValido(String valor) {
    final ano = int.tryParse(valor);
    if (ano == null) return false;

    final anoAtual = DateTime.now().year;
    return ano >= anoAtual;
  }

  bool _mesAnoValido(String mesTexto, String anoTexto) {
    final mes = int.tryParse(mesTexto);
    final ano = int.tryParse(anoTexto);

    if (mes == null || ano == null) return false;
    if (mes < 1 || mes > 12) return false;

    final agora = DateTime.now();
    final validade = DateTime(ano, mes + 1, 0);

    return validade.isAfter(agora);
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _numeroCtrl.dispose();
    _mesCtrl.dispose();
    _anoCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  String _somenteNumeros(String valor) {
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _moeda(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Widget _linhaResumo(String titulo, double valor, {bool destaque = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: destaque ? 18 : 15,
              fontWeight: destaque ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
        Text(
          _moeda(valor),
          style: TextStyle(
            fontSize: destaque ? 18 : 15,
            fontWeight: destaque ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _resumoPagamento() {
    final titulo = widget.tipoPagamento == 'DEBIT_CARD'
        ? 'Cartão de débito'
        : 'Cartão de crédito';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card, size: 24),
              const SizedBox(width: 10),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _linhaResumo('Total a pagar', widget.totalPagar, destaque: true),
        ],
      ),
    );
  }

  InputDecoration _decoracao(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _dadosCartaoBox() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dados do cartão',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _nomeCtrl,
            decoration: _decoracao('Nome do titular', Icons.person_outline),
            maxLength: 80,
            validator: (value) {
              final v = (value ?? '').trim();

              if (v.isEmpty) {
                return 'Informe o nome do titular';
              }

              if (v.length < 3) {
                return 'Nome muito curto';
              }

              return null;
            },
          ),

          const SizedBox(height: 14),

          TextFormField(
            controller: _numeroCtrl,
            keyboardType: TextInputType.number,
            maxLength: 19,
            decoration: _decoracao(
              'Número do cartão',
              Icons.credit_card,
            ).copyWith(counterText: ''),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _mesCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 2,
                  decoration: _decoracao('Mês', Icons.date_range),
                  validator: (value) {
                    final v = int.tryParse(value ?? '');
                    if (v == null || v < 1 || v > 12) return 'Mês inválido';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _mesCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 2,
                  decoration: _decoracao(
                    'Mês',
                    Icons.date_range,
                  ).copyWith(counterText: ''),
                  validator: (value) {
                    final v = int.tryParse(value ?? '');

                    if (v == null || v < 1 || v > 12) {
                      return 'Mês inválido';
                    }

                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cvvCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: _decoracao('CVV', Icons.lock_outline),
                  validator: (value) {
                    final n = _somenteNumeros(value ?? '');
                    if (n.length < 3 || n.length > 4) return 'CVV inválido';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> pagar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => carregando = true);

    try {
      final clienteId = await authStorage.obterClienteId();

      if (clienteId == null || clienteId == 0) {
        throw Exception('Cliente não identificado');
      }

      if (!_mesAnoValido(_mesCtrl.text.trim(), _anoCtrl.text.trim())) {
        throw Exception('Cartão vencido');
      }

      await apiService.pagarComCartao(
        clienteId: clienteId,
        organizacaoId: widget.loja.organizacaoId,
        lojaId: widget.loja.id,
        encryptedCard: '',
        securityCode: _somenteNumeros(_cvvCtrl.text),
        tipoPagamento: widget.tipoPagamento,
      );

      if (!mounted) return;

      final resultado = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PagamentoSucessoScreen()),
      );

      if (resultado == true && context.mounted) {
        CarteiraBadgeNotifier.atualizar();

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _resumoPagamento(),
            const SizedBox(height: 20),
            _dadosCartaoBox(),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: carregando ? null : pagar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: carregando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Finalizar pagamento',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
